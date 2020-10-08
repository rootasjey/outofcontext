import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:memorare/actions/quotes.dart';
import 'package:memorare/actions/quotidians.dart';
import 'package:memorare/components/error_container.dart';
import 'package:memorare/components/quote_row_with_actions.dart';
import 'package:memorare/components/simple_appbar.dart';
import 'package:memorare/components/sliver_loading_view.dart';
import 'package:memorare/components/web/app_icon_header.dart';
import 'package:memorare/components/web/empty_content.dart';
import 'package:memorare/components/web/fade_in_y.dart';
import 'package:memorare/router/route_names.dart';
import 'package:memorare/state/colors.dart';
import 'package:memorare/state/user_state.dart';
import 'package:memorare/types/enums.dart';
import 'package:memorare/types/quote.dart';
import 'package:memorare/utils/app_localstorage.dart';
import 'package:memorare/utils/snack.dart';
import 'package:supercharged/supercharged.dart';

class RecentQuotes extends StatefulWidget {
  final bool showNavBackIcon;

  RecentQuotes({this.showNavBackIcon = true});
  @override
  RecentQuotesState createState() => RecentQuotesState();
}

class RecentQuotesState extends State<RecentQuotes> {
  bool canManage = false;
  bool descending = true;
  bool hasNext = true;
  bool hasErrors = false;
  bool isConnected = false;
  bool isLoading = false;
  bool isLoadingMore = false;

  final pageRoute = QuotesRoute;

  final limit = 30;
  List<Quote> quotes = [];
  String lang = 'en';

  var itemsStyle = ItemsLayout.list;
  var lastDoc;
  var scrollController = ScrollController();

  @override
  initState() {
    super.initState();
    getSavedProps();
    fetchPermissions();
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
          onRefresh: () async {
            await fetch();
            return null;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollNotif) {
              if (scrollNotif.metrics.pixels <
                  scrollNotif.metrics.maxScrollExtent) {
                return false;
              }

              if (hasNext && !isLoadingMore) {
                fetchMore();
              }

              return false;
            },
            child: CustomScrollView(
              controller: scrollController,
              slivers: <Widget>[
                appBar(),
                body(),
              ],
            ),
          )),
    );
  }

  Widget appBar() {
    return SimpleAppBar(
      title: TextButton.icon(
        onPressed: () {
          scrollController.animateTo(
            0,
            duration: 250.milliseconds,
            curve: Curves.easeIn,
          );
        },
        icon: AppIconHeader(
          padding: EdgeInsets.zero,
          size: 30.0,
        ),
        label: Text(
          'Recent',
          style: TextStyle(
            fontSize: 22.0,
          ),
        ),
      ),
      showNavBackIcon: widget.showNavBackIcon,
      subHeader: Observer(
        builder: (context) {
          return Wrap(
            spacing: 10.0,
            children: <Widget>[
              FadeInY(
                beginY: 10.0,
                delay: 2.0,
                child: ChoiceChip(
                  label: Text(
                    'First added',
                    style: TextStyle(
                      color:
                          !descending ? Colors.white : stateColors.foreground,
                    ),
                  ),
                  tooltip: 'Order by first added',
                  selected: !descending,
                  selectedColor: stateColors.primary,
                  onSelected: (selected) {
                    if (!descending) {
                      return;
                    }

                    descending = false;
                    fetch();

                    appLocalStorage.setPageOrder(
                      descending: descending,
                      pageRoute: pageRoute,
                    );
                  },
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 2.5,
                child: ChoiceChip(
                  label: Text(
                    'Last added',
                    style: TextStyle(
                      color: descending ? Colors.white : stateColors.foreground,
                    ),
                  ),
                  tooltip: 'Order by most recently added',
                  selected: descending,
                  selectedColor: stateColors.primary,
                  onSelected: (selected) {
                    if (descending) {
                      return;
                    }

                    descending = true;
                    fetch();

                    appLocalStorage.setPageOrder(
                      descending: descending,
                      pageRoute: pageRoute,
                    );
                  },
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 3.0,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 10.0,
                    left: 20.0,
                    right: 20.0,
                  ),
                  child: Container(
                    height: 25,
                    width: 2.0,
                    color: stateColors.foreground.withOpacity(0.5),
                  ),
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 3.5,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: DropdownButton<String>(
                    elevation: 2,
                    value: lang,
                    isDense: true,
                    underline: Container(
                      height: 0,
                      color: Colors.deepPurpleAccent,
                    ),
                    icon: Icon(Icons.keyboard_arrow_down),
                    style: TextStyle(
                      color: stateColors.foreground.withOpacity(0.6),
                      fontFamily: 'Comfortaa',
                      fontSize: 20.0,
                    ),
                    onChanged: (String newLang) {
                      lang = newLang;
                      fetch();
                    },
                    items: ['en', 'fr'].map((String value) {
                      return DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.toUpperCase(),
                          ));
                    }).toList(),
                  ),
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 3.2,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 10.0,
                    left: 10.0,
                    right: 10.0,
                  ),
                  child: Container(
                    height: 25,
                    width: 2.0,
                    color: stateColors.foreground.withOpacity(0.5),
                  ),
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 3.5,
                child: IconButton(
                  onPressed: () {
                    if (itemsStyle == ItemsLayout.list) {
                      return;
                    }

                    setState(() {
                      itemsStyle = ItemsLayout.list;
                    });

                    appLocalStorage.saveItemsStyle(
                      pageRoute: pageRoute,
                      style: ItemsLayout.list,
                    );
                  },
                  icon: Icon(Icons.list),
                  color: itemsStyle == ItemsLayout.list
                      ? stateColors.primary
                      : stateColors.foreground.withOpacity(0.5),
                ),
              ),
              FadeInY(
                beginY: 10.0,
                delay: 3.5,
                child: IconButton(
                  onPressed: () {
                    if (itemsStyle == ItemsLayout.grid) {
                      return;
                    }

                    setState(() {
                      itemsStyle = ItemsLayout.grid;
                    });

                    appLocalStorage.saveItemsStyle(
                      pageRoute: pageRoute,
                      style: ItemsLayout.grid,
                    );
                  },
                  icon: Icon(Icons.grid_on),
                  color: itemsStyle == ItemsLayout.grid
                      ? stateColors.primary
                      : stateColors.foreground.withOpacity(0.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget body() {
    if (isLoading) {
      return SliverLoadingView();
    }

    if (!isLoading && hasErrors) {
      return errorView();
    }

    if (quotes.length == 0) {
      return emptyView();
    }

    if (itemsStyle == ItemsLayout.grid) {
      return sliverGrid();
    }

    return sliverList();
  }

  Widget emptyView() {
    return SliverList(
      delegate: SliverChildListDelegate([
        FadeInY(
          delay: 2.0,
          beginY: 50.0,
          child: EmptyContent(
            icon: Opacity(
              opacity: .8,
              child: Icon(
                Icons.sentiment_neutral,
                size: 120.0,
                color: Color(0xFFFF005C),
              ),
            ),
            title: "You've no quote in validation at this moment",
            subtitle: 'They will appear after you propose a new quote',
            onRefresh: () => fetch(),
          ),
        ),
      ]),
    );
  }

  Widget errorView() {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.only(top: 150.0),
          child: ErrorContainer(
            onRefresh: () => fetch(),
          ),
        ),
      ]),
    );
  }

  Widget sliverGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300.0,
          mainAxisSpacing: 20.0,
          crossAxisSpacing: 20.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final quote = quotes.elementAt(index);

            return QuoteRowWithActions(
              quote: quote,
              componentType: ItemComponentType.card,
              onBeforeDeletePubQuote: () {
                setState(() {
                  quotes.removeAt(index);
                });
              },
              onAfterDeletePubQuote: (bool success) {
                if (!success) {
                  quotes.insert(index, quote);

                  showSnack(
                    context: context,
                    message: "Couldn't delete the temporary quote.",
                    type: SnackType.error,
                  );
                }
              },
            );
          },
          childCount: quotes.length,
        ),
      ),
    );
  }

  Widget sliverList() {
    final horPadding = MediaQuery.of(context).size.width < 700.00 ? 20.0 : 70.0;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final quote = quotes.elementAt(index);

          return QuoteRowWithActions(
            quote: quote,
            padding: EdgeInsets.symmetric(
              horizontal: horPadding,
              vertical: 30.0,
            ),
            quotePageType: QuotePageType.published,
          );
        },
        childCount: quotes.length,
      ),
    );
  }

  void addQuotidianAction(Quote quote) async {
    final success = await addToQuotidians(
      quote: quote,
      lang: lang,
    );

    if (success) {
      showSnack(
        context: context,
        message: 'Quote successfully added.',
        type: SnackType.success,
      );
      return;
    }

    showSnack(
      context: context,
      message: 'Sorry, an error occurred while adding the quotes to quotidian.',
      type: SnackType.error,
    );
  }

  void fetchPermissions() async {
    try {
      final userAuth = await userState.userAuth;

      if (userAuth == null) {
        return;
      }

      final user =
          await Firestore().collection('users').document(userAuth.uid).get();

      if (user == null) {
        return;
      }

      setState(() {
        isConnected = true;
        canManage = user.data['rights']['user:managequotidian'];
      });
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  void deleteAction(Quote quote) async {
    int index = quotes.indexOf(quote);

    setState(() {
      quotes.removeAt(index);
    });

    final success = await deleteQuote(quote: quote);

    if (!success) {
      quotes.insert(index, quote);

      showSnack(
        context: context,
        message: "Couldn't delete the temporary quote.",
        type: SnackType.error,
      );
    }
  }

  Future fetch() async {
    setState(() {
      isLoading = true;
      quotes.clear();
    });

    try {
      final snapshot = await Firestore.instance
          .collection('quotes')
          .where('lang', isEqualTo: lang)
          .orderBy('createdAt', descending: descending)
          .limit(30)
          .getDocuments();

      if (snapshot.documents.isEmpty) {
        setState(() {
          hasNext = false;
          isLoading = false;
        });

        return;
      }

      snapshot.documents.forEach((doc) {
        final data = doc.data;
        data['id'] = doc.documentID;

        final quote = Quote.fromJSON(data);
        quotes.add(quote);
      });

      lastDoc = snapshot.documents.last;

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      debugPrint(error.toString());

      setState(() {
        isLoading = false;
      });
    }
  }

  void fetchMore() async {
    if (lastDoc == null) {
      return;
    }
    isLoadingMore = true;

    try {
      final snapshot = await Firestore.instance
          .collection('quotes')
          .where('lang', isEqualTo: lang)
          .orderBy('createdAt', descending: descending)
          .startAfterDocument(lastDoc)
          .limit(30)
          .getDocuments();

      if (snapshot.documents.isEmpty) {
        setState(() {
          hasNext = false;
          isLoadingMore = false;
        });

        return;
      }

      snapshot.documents.forEach((doc) {
        final data = doc.data;
        data['id'] = doc.documentID;

        final quote = Quote.fromJSON(data);
        quotes.add(quote);
      });

      lastDoc = snapshot.documents.last;

      setState(() {
        isLoadingMore = false;
      });
    } catch (error) {
      debugPrint(error.toString());

      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void getSavedProps() {
    lang = appLocalStorage.getPageLang(pageRoute: pageRoute);
    descending = appLocalStorage.getPageOrder(pageRoute: pageRoute);
    itemsStyle = appLocalStorage.getItemsStyle(pageRoute);
  }

  void showDeleteDialog(Quote quote) {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(
              'Confirm deletion?',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 40.0,
            ),
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(3.0),
                      ),
                    ),
                    color: stateColors.softBackground,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 15.0,
                      ),
                      child: Text(
                        'NO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(left: 15.0)),
                  RaisedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      deleteAction(quote);
                    },
                    color: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(3.0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 15.0,
                      ),
                      child: Text(
                        'YES',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
  }
}