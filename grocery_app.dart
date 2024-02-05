import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:listapp/grocery_item.dart';
import 'package:listapp/search_bar.dart';
import 'package:listapp/recipe.dart';
import 'package:listapp/recipestepspage.dart';
import 'package:fraction/fraction.dart';
import 'main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'l10n/l10n.dart';
import 'servings_selector.dart';
import 'timer_widget.dart';
import 'package:bordered_text/bordered_text.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:flutter/services.dart';
import 'package:listapp/grocery_item.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'provider/locale_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class GroceryApp extends StatefulWidget {
  final List<GroceryItem> groceryItems;

  const GroceryApp({Key? key, required this.groceryItems}) : super(key: key);

  @override
  _GroceryAppState createState() => _GroceryAppState();
}

late Timer _adTimer;
late Timer _reviewTimer;
late SharedPreferences _prefs;

class _GroceryAppState extends State<GroceryApp> {
  int recipeadcounter = 0;
  int showninterstitaladtimer = 0;

  void _showaddonrecipebutton() {
    if (recipeadcounter == 2 || recipeadcounter % 5 == 0) {
      // Show the ad every 3rd time
      setState(() {
        _showInterstitialAd();
      });
    }
  }

  void stoptimerinsterstitelads() {
    if (showninterstitaladtimer < 3) {
      showninterstitaladtimer++;
      print('the showninterstitaladtimer is at $showninterstitaladtimer');
      setState(() {
        _showInterstitialAd();
      });
    }
  }

  void _showReviewDialog() {
    final List<String> positiveAdjectives = [
      'amazing',
      'awesome',
      'fantastic',
      'incredible',
      'outstanding',
      'phenomenal',
      'spectacular',
      'terrific',
      'wonderful',
      'marvelous'
    ];

    final String randomAdjective =
        positiveAdjectives[Random().nextInt(positiveAdjectives.length)];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enjoying the App?',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.0),
                Text(
                  'You\'re using this app and it\'s $randomAdjective!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.0),
                Text(
                  'Why not spread the love? Leave us a review on the Play Store!',
                ),
                SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text('Maybe later'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _prefs.setBool('showReviewDialog', false);
                        _launchPlayStoreReview();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text('Review now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchPlayStoreReview() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.JKWSolutions.listapp';

    if (await canLaunch(playStoreUrl)) {
      await launch(playStoreUrl);
    } else {
      throw 'Could not launch $playStoreUrl';
    }
  }

  void _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool _firstLaunch = true;

  final String interstitialAdUnitId = "ca-app-pub-3940256099942544/1033173712";
  bool isLoaded = false;
  late BannerAd bannerAd;
  late InterstitialAd _interstitialAd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          // Set the state to loaded.
          setState(() {
            isLoaded = true;
          });

          // Print a message to the console.
          print("Banner Ad Loaded");
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // Dispose of the ad.
          ad.dispose();
        },
      ),
      request: AdRequest(),
    );

    bannerAd!.load();
  }

  @override
  void dispose() {
    _savePreviousList();
    bannerAd?.dispose();
    super.dispose();
    _reviewTimer.cancel();
  }

  void _startReviewTimer() {
    Timer(Duration(seconds: 500), () {
      bool showDialog = _prefs.getBool('showReviewDialog') ?? true;
      if (showDialog) {
        if (mounted) {
          _showReviewDialog();
        }
      }
    });
  }

  bool showArrow = true;
  List<GroceryItem> _groceryList = [];

  @override
  void initState() {
    super.initState();
    _initPreferences();
    _loadGroceryList();
    _loadInterstitialAd();
    _loadPreviousList();
    _startReviewTimer();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          // Keep a reference to the ad so i can show it later
          interstitialAd = ad;
          print("InterstitialAd Loaded");
          // Set the full-screen content callback
          _setFullScreenContentCallback();
          startTimer();
        },
        onAdFailedToLoad: (LoadAdError loadAdError) {
          // Ad failed to load
          print("Interstitial ad failed to load: $loadAdError");
        },
      ),
    );
  }

  InterstitialAd? interstitialAd;
  Timer? _timer;

  void startTimer() {
    _timer?.cancel(); // cancel any existing timer

    if (showninterstitaladtimer == 0) {
      _timer = Timer.periodic(Duration(seconds: 66), (timer) {
        stoptimerinsterstitelads();
      });
    } else {
      _timer = Timer.periodic(Duration(seconds: 177), (timer) {
        stoptimerinsterstitelads();
      });
    }
  }

  void _setFullScreenContentCallback() {
    interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print("$ad onAdShowedFullScreenContent");
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print("$ad onAdDismissedFullScreenContent");
        // Dispose the dismissed ad
        ad.dispose();
        // Load a new interstitial ad
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print("$ad onAdFailedToShowFullScreenContent: $error");
        // Dispose the failed ad
        ad.dispose();
        // Load a new interstitial ad
        _loadInterstitialAd();
      },
      onAdImpression: (InterstitialAd ad) => print("$ad Impression occurred"),
    );
  }

  void _showInterstitialAd() {
    if (interstitialAd == null) {
      print("Ad not ready!");
      return;
    }
    interstitialAd!.show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildAddItemsPage(),
                _buildGroceryListPage(),
                buildRecipesPage(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: GNav(
              rippleColor: Colors.grey.withOpacity(0.1),
              hoverColor: Colors.grey.withOpacity(0.1),
              gap: 8,
              activeColor: Colors.white,
              iconSize: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: Colors.blue,
              tabs: [
                GButton(
                  icon: Icons.shopping_cart,
                  text: AppLocalizations.of(context)!.addItems,
                ),
                GButton(
                  icon: Icons.shopping_bag,
                  text: AppLocalizations.of(context)!.groceryList,
                ),
                GButton(
                  icon: Icons.restaurant_menu,
                  text: AppLocalizations.of(context)!.recipes,
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: _onItemTapped,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadGroceryList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? groceryListData = prefs.getString('groceryList');
    if (groceryListData != null) {
      setState(() {
        List<dynamic> decodedData = jsonDecode(groceryListData);
        _groceryList =
            decodedData.map((data) => GroceryItem.fromJson(data)).toList();
      });
    }
    bool firstLaunch = prefs.getBool('firstLaunch') ?? true;
    if (firstLaunch) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Get Started!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Here\'s how to use the app:',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  '1. Choose ingredients',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Add the ingredients you need for your recipes to your grocery list.',
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
                SizedBox(height: 16.0),
                Text(
                  '2. Add Recipes with Custom Servings',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Enter your recipes and specify the number of servings you need. The app will calculate the amount of each ingredient you need to buy.',
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
                SizedBox(height: 16.0),
                Text(
                  '3. Save to Grocery List',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Save your grocery list and use it when you go shopping!',
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Vibration.vibrate(duration: 50);
                  Navigator.pop(context);
                },
                child: Text('OK'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.green[700],
                  textStyle: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          );
        },
      );
      await prefs.setBool('firstLaunch', false);
    }
  }

  Future<void> _saveGroceryList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String groceryListData =
        jsonEncode(_groceryList.map((item) => item.toJson()).toList());
    await prefs.setString('groceryList', groceryListData);
  }

  String? _selectedCategory;
  List<GroceryItem>? _itemsForSelectedCategory;
  GroceryItem? _selectedIngredient;

  void _addCustomIngredient() {
    String? itemName;
    double? itemQuantity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Custom Ingredient'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.name,
                  ),
                  onChanged: (value) {
                    itemName = value;
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.quantity,
                      style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w400),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Vibration.vibrate(duration: 50);
                            setState(() {
                              itemQuantity = (itemQuantity ?? 1) + 1;
                            });
                            _saveGroceryList();
                          },
                          icon: Icon(Icons.add),
                          color: Colors.green,
                        ),
                        Text(
                          '${itemQuantity?.toStringAsFixed(0) ?? "1"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Open Sans',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Vibration.vibrate(duration: 50);
                            setState(() {
                              itemQuantity = (itemQuantity ?? 1) > 1
                                  ? (itemQuantity ?? 1) - 1
                                  : 1;
                            });
                            _saveGroceryList();
                          },
                          icon: Icon(Icons.remove),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Vibration.vibrate(duration: 50);
                  if (itemName != null) {
                    final newIngredient = GroceryItem(
                      name: itemName!,
                      category: 'Other',
                      unit: '',
                      quantity: itemQuantity ?? 1.0,
                    );
                    setState(() {
                      _groceryList.add(newIngredient);
                    });
                    Navigator.pop(context);
                    _saveGroceryList();
                  }
                },
                child: Text('Add'),
                style: ElevatedButton.styleFrom(
                  primary: Color(0xFF00BF63),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          );
        });
      },
    );
  }

  Future<void> _savePreviousList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encodedList =
        jsonEncode(_previousList.map((item) => item.toJson()).toList());
    await prefs.setString(
        AppLocalizations.of(context)!.previousList, encodedList);
  }

  List<GroceryItem> _previousList = [];

  void _showPreviousList() {
    if (_previousList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.noPreviousList,
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(top: 80.0),
        duration: Duration(seconds: 1),
      ));
      return;
    }

    final uniqueNames = _previousList.map((item) => item.name).toSet();
    final uniqueList = uniqueNames.map((name) {
      final items = _previousList.where((item) => item.name == name).toList();
      final totalQuantity =
          items.fold<int>(0, (sum, item) => sum + item.quantity.toInt());
      final unit = items.first.unit;
      return GroceryItem(
        name: name,
        category: items.first.category,
        purchased: true,
        quantity: totalQuantity.toDouble(),
        unit: unit,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WillPopScope(
          onWillPop: () async {
            // Save the previous list when the user presses the back button
            final SharedPreferences prefs =
                await SharedPreferences.getInstance();
            final String previousListJson = jsonEncode(_previousList);
            await prefs.setString(
                AppLocalizations.of(context)!.previousList, previousListJson);
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Color(0xFF00BF63),
              title: Text(
                AppLocalizations.of(context)!.previousList,
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    Vibration.vibrate(duration: 50);
                    setState(() {
                      _previousList.clear();
                      _previousList = [];
                      _savePreviousList();
                    });
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.listCleared,
                            style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(top: 80.0),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: ListView.builder(
              itemCount: uniqueList.length,
              itemBuilder: (context, index) {
                final item = uniqueList[index];
                return _buildPreviousListItem(item);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPreviousList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? previousListJson =
        prefs.getString(AppLocalizations.of(context)!.previousList);
    if (previousListJson != null) {
      final List<dynamic> previousListData = jsonDecode(previousListJson);
      final List<GroceryItem> previousList =
          previousListData.map((data) => GroceryItem.fromJson(data)).toList();
      setState(() {
        _previousList = previousList;
      });
    }
  }

  bool isFirstTimeAddingItem = true;

  Widget _buildAddItemsPage() {
    final itemsToDisplay = widget.groceryItems
        .where((item) =>
            _selectedCategory == null || item.category == _selectedCategory)
        .toList();

    return Builder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.shopping_cart),
                SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.addItems),
              ],
            ),
            backgroundColor: Color(0xFF00BF63),
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Column(
                  children: [
                    SearchBar2(
                      groceryItems: widget.groceryItems,
                      onSearchResults: (results) {
                        setState(() {
                          _itemsForSelectedCategory = results;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                  right: 5,
                  left: 5,
                  top: 20,
                ),
                child: GestureDetector(
                  onTap: () {
                    Vibration.vibrate(duration: 50);
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8.0),
                            Text(
                              AppLocalizations.of(context)!.selectCategory,
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Divider(height: 0),
                            Expanded(
                              child: ListView(
                                children: [
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.all +
                                            ' \u{1F3EA}',
                                        style: TextStyle(fontSize: 18.0)),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.all +
                                            ' \u{1F3EA}',
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.drinks),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.drinks,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(AppLocalizations.of(context)!
                                        .vegetables),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!
                                            .vegetables,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.fruits),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.fruits,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.meats),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.meats,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.dairy),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.dairy,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.pantry),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.pantry,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(AppLocalizations.of(context)!
                                        .snacksSweets),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!
                                            .snacksSweets,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(AppLocalizations.of(context)!
                                        .frozenFood),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!
                                            .frozenFood,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(AppLocalizations.of(context)!
                                        .cannedFoods),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!
                                            .cannedFoods,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.desserts),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.desserts,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(
                                        AppLocalizations.of(context)!.kitchen),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.kitchen,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title:
                                        Text(AppLocalizations.of(context)!.wc),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!.wc,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title: Text(AppLocalizations.of(context)!
                                        .electronics),
                                    onTap: () {
                                      Vibration.vibrate(duration: 50);
                                      Navigator.pop(
                                        context,
                                        AppLocalizations.of(context)!
                                            .electronics,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ).then((selectedValue) {
                      setState(() {
                        _selectedCategory = selectedValue;
                        if (_selectedCategory ==
                            AppLocalizations.of(context)!.all + ' \u{1F3EA}') {
                          _itemsForSelectedCategory = widget.groceryItems;
                        } else {
                          _itemsForSelectedCategory = widget.groceryItems
                              .where((item) => item.category == selectedValue)
                              .toList();
                        }
                      });
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 67, 138, 255),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, color: Colors.white),
                          const SizedBox(width: 8.0),
                          Text(
                            _selectedCategory ??
                                AppLocalizations.of(context)!.chooseCategory,
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_itemsForSelectedCategory != null)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0),
                    child: ListView.builder(
                      itemCount: _itemsForSelectedCategory!.length,
                      itemBuilder: (context, index) {
                        final item = _itemsForSelectedCategory![index];
                        final groceryItemIndex = _groceryList.indexWhere(
                            (groceryItem) => groceryItem.name == item.name);
                        final groceryItem = groceryItemIndex != -1
                            ? _groceryList[groceryItemIndex]
                            : null;

                        return GestureDetector(
                          onTap: () {
                            Vibration.vibrate(duration: 50);
                            setState(() {
                              if (groceryItem != null) {
                                _groceryList[groceryItemIndex] =
                                    groceryItem.copyWith(
                                  quantity: groceryItem.quantity + 1,
                                );
                              } else {
                                _selectedIngredient = item;
                                if (isFirstTimeAddingItem) {
                                  _groceryList.add(item.copyWith(quantity: 1));
                                  isFirstTimeAddingItem = false;
                                } else {
                                  _groceryList.add(item);
                                }
                              }
                              _saveGroceryList();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  groceryItem != null
                                      ? AppLocalizations.of(context)!.added +
                                          ' ${groceryItem.name}'
                                      : AppLocalizations.of(context)!.added +
                                          ' ${item.name}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.blue,
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.only(top: 80.0),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.only(left: 0, bottom: 2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 1,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(left: 10),
                                            child: Text(
                                              item.name,
                                              textAlign: TextAlign.left,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontFamily: 'Open Sans',
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (groceryItem != null)
                                          Row(
                                            key: ValueKey(groceryItem.quantity),
                                            children: [
                                              AnimatedSwitcher(
                                                duration:
                                                    Duration(milliseconds: 50),
                                                transitionBuilder:
                                                    (Widget child,
                                                        Animation<double>
                                                            animation) {
                                                  return ScaleTransition(
                                                    scale: animation,
                                                    child: FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                                child: InkWell(
                                                  onTap: () {
                                                    Vibration.vibrate(
                                                        duration: 50);
                                                    final scaffold =
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          AppLocalizations.of(
                                                                      context)!
                                                                  .removed +
                                                              ' ${groceryItem.name}',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                        backgroundColor:
                                                            Colors.blue,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        margin: EdgeInsets.only(
                                                            top: 80.0),
                                                        duration: Duration(
                                                            seconds: 1),
                                                      ),
                                                    );

                                                    setState(() {
                                                      if (groceryItem.quantity >
                                                          1) {
                                                        _groceryList[
                                                                groceryItemIndex] =
                                                            groceryItem
                                                                .copyWith(
                                                          quantity: groceryItem
                                                                  .quantity -
                                                              1,
                                                        );
                                                      } else {
                                                        _groceryList.removeAt(
                                                            groceryItemIndex);
                                                      }
                                                      _saveGroceryList();
                                                    });

                                                    Future.delayed(Duration(
                                                            seconds: 1))
                                                        .then((_) {
                                                      scaffold.close();
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 30,
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.red,
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.remove,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                '${groceryItem.quantity.toInt()}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  fontFamily: 'Open Sans',
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              InkWell(
                                                onTap: () {
                                                  Vibration.vibrate(
                                                      duration: 50);
                                                  setState(() {
                                                    _groceryList[
                                                            groceryItemIndex] =
                                                        groceryItem.copyWith(
                                                      quantity:
                                                          groceryItem.quantity +
                                                              1,
                                                    );
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          AppLocalizations.of(
                                                                      context)!
                                                                  .added +
                                                              ' ${groceryItem.name}',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                        backgroundColor:
                                                            Colors.blue,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        margin: EdgeInsets.only(
                                                            top: 80.0),
                                                        duration: Duration(
                                                            seconds: 1),
                                                      ),
                                                    );
                                                    _saveGroceryList();
                                                  });
                                                },
                                                child: Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.green,
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.add,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    height: 0,
                                    color: Colors.blueGrey,
                                    indent: 1,
                                    endIndent: 1,
                                    thickness: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (isLoaded)
                Container(
                  height: 50,
                  child: AdWidget(ad: bannerAd!),
                ),
            ],
          ),
          floatingActionButton: Align(
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.only(left: 32.0, bottom: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _addCustomIngredient();
                        _saveGroceryList();
                      },
                      child: Icon(Icons.add, size: 40),
                      backgroundColor: Color.fromARGB(255, 67, 138, 255),
                    ),
                  ),
                  SizedBox(height: 2),
                  BorderedText(
                    strokeWidth: 2.0,
                    strokeColor: Colors.white,
                    child: Text(
                      AppLocalizations.of(context)!.customItem,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Color.fromARGB(255, 67, 138, 255),
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            offset: Offset(1.0, 1.0),
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 1.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool isItemDismissed = false;

  bool _animationShown = false;

  Widget _buildGroceryListPage() {
    // Sort grocery items by category

    _groceryList.sort((a, b) => a.category.compareTo(b.category));

    // Group grocery items by category
    final itemsByCategory = <String, List<GroceryItem>>{};
    for (final item in _groceryList) {
      if (!itemsByCategory.containsKey(item.category)) {
        itemsByCategory[item.category] = [];
      }
      itemsByCategory[item.category]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              Icon(Icons.shopping_bag),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.groceryList,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        backgroundColor: Color(0xFF00BF63),
        actions: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  AppLocalizations.of(context)!.previousList,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Hero(
                tag: 'historyButton',
                child: IconButton(
                  icon: Icon(Icons.history),
                  onPressed: () {
                    _showPreviousList();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_groceryList.isEmpty)
            Center(
              child: Image.asset(
                'assets/animations/GlistEmpty.gif', // If list empty show gif
                width: 1200.0,
                height: 500.0,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: ListView.builder(
                itemCount: itemsByCategory.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      color: Colors.white10,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 20.0, bottom: 10.0, left: 8.0, right: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      child: AutoSizeText(
                                        AppLocalizations.of(context)!
                                            .recipeAndShoppingItems,
                                        style: TextStyle(
                                          fontSize: 27.0,
                                          color: Colors.blue,
                                          fontFamily: 'Open Sans',
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                          letterSpacing: 2.0,
                                          wordSpacing: 3.0,
                                          shadows: [
                                            Shadow(
                                                color: Colors.grey,
                                                offset: Offset(2.0, 2.0),
                                                blurRadius: 2.0),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2.0),
                          Divider(
                            color: Colors.green,
                            thickness: 2.0,
                            height: 30.0,
                            indent: 16.0,
                            endIndent: 16.0,
                          ),
                        ],
                      ),
                    );
                  }

                  final category = itemsByCategory.keys.elementAt(index - 1);
                  final items = itemsByCategory[category]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5.0, left: 16.0),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 22.0,
                            fontFamily: 'Open Sans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ...items.map((item) => Container(
                            decoration: BoxDecoration(
                              color: Color(0xFAFAFAFA),
                              border: Border(
                                top: BorderSide(color: Colors.grey[400]!),
                                bottom: BorderSide(color: Colors.grey[400]!),
                              ),
                            ),
                            child: item.category == 'Recipe'
                                ? Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                            color: Colors.grey[400]!),
                                        bottom: BorderSide(
                                            color: Colors.grey[400]!),
                                      ),
                                    ),
                                    child: _buildRecipeGroceryListItem(item),
                                  )
                                : _buildGroceryListItem(item),
                          )),
                      SizedBox(height: 16.0),
                    ],
                  );
                },
                padding: const EdgeInsets.only(bottom: 80.0),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: isItemDismissed
                ? Container() // Returning an empty container when item is dismissed
                : Dismissible(
                    key: UniqueKey(),
                    direction: DismissDirection.horizontal,
                    onDismissed: (direction) {
                      setState(() {
                        isItemDismissed = true;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                          bottom: 58.0, left: 10.0, right: 10.0),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_right,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 1.0),
                                Text(
                                  AppLocalizations.of(context)!.swipeToDelete,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.0,
                                    fontFamily: 'Open Sans',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            bottom: _groceryList.isEmpty ? 16.0 : 55.0,
            right: _groceryList.isEmpty ? -80.0 : 16.0,
            child: Container(
              height: 60.0,
              width: 60.0,
              child: RawMaterialButton(
                onPressed: () {
                  Vibration.vibrate(duration: 50);
                  setState(() {
                    _groceryList.clear();
                    _saveGroceryList();
                  });
                },
                shape: CircleBorder(),
                padding: EdgeInsets.all(15.0),
                fillColor: Colors.red,
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 30.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isChecked = false;

  Widget _buildGroceryListItem(GroceryItem item, [int? quantity]) {
    final quantityText = _formattedQuantity(item.quantity);
    final nameStyle = TextStyle(
      fontSize: 18.0,
      fontFamily: 'Open Sans',
      fontWeight: FontWeight.w400,
      decoration: item.purchased ? TextDecoration.lineThrough : null,
    );
    final quantityStyle = TextStyle(
      fontSize: 14.0,
      fontFamily: 'Open Sans',
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    final unitStyle = TextStyle(
      fontSize: 14.0,
      fontFamily: 'Open Sans',
      color: Colors.blueGrey,
      fontWeight: FontWeight.w700,
    );

    if (item.fromRecipe) {
      return Dismissible(
        key: UniqueKey(),
        background: Container(
          color: Color.fromARGB(255, 255, 1, 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.delete, color: Colors.white),
              SizedBox(width: 16.0),
            ],
          ),
        ),
        onDismissed: (_) {
          setState(() {
            _groceryList.remove(item);
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: nameStyle.copyWith(
                        color: item.purchased ? Colors.green : Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          quantityText,
                          style: quantityStyle,
                        ),
                        Text(
                          ' ' + item.unit,
                          style: unitStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.5,
                child: Checkbox(
                  value: item.purchased,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    setState(() {
                      item.purchased = value ?? false;
                      _isChecked = item.purchased;
                      if (item.purchased) {
                        _previousList.add(GroceryItem(
                          name: item.name,
                          category: item.category,
                          purchased: true,
                        ));
                      }
                    });
                  },
                ),
              )
            ],
          ),
        ),
      );
    } else {
      return _buildRecipeGroceryListItem(item);
    }
  }

  Widget _buildRecipeGroceryListItem(GroceryItem item) {
    final unitOptions = [
      'unit',
      'kg',
      'pounds',
      'bottle',
      'gallon',
      'liter',
      'can',
      'piece',
      'pack',
      'dozen',
      'bag',
      'box',
      'bundle',
      'cup',
    ];

    void updateUnit(String? newUnit) {
      if (newUnit != null) {
        setState(() {
          // Find the index of the item in the list
          int index = _groceryList.indexOf(item);
          // Create a copy of the item with the updated unit
          GroceryItem updatedItem = item.copyWith(unit: newUnit);
          // Replace the old item with the updated item
          _groceryList[index] = updatedItem;
        });
      }
      _saveGroceryList();
    }

    return Dismissible(
      key: ValueKey(item),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        return true;
      },
      onDismissed: (direction) {
        setState(() {
          _groceryList.remove(item);
        });
      },
      background: Container(
        color: Colors.red,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.delete,
              color: Colors.white,
              size: 30.0,
            ),
            SizedBox(width: 20.0),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 20.0),
            Icon(
              Icons.delete,
              color: Colors.white,
              size: 30.0,
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.0),
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Open Sans',
                      decoration:
                          item.purchased ? TextDecoration.lineThrough : null,
                      color: item.purchased ? Colors.green : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.0),
                  DropdownButton<String>(
                    value: unitOptions.contains(item.unit) ? item.unit : 'unit',
                    onChanged: updateUnit,
                    items: unitOptions
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(color: Colors.black, fontSize: 16.0),
                        ),
                      );
                    }).toList(),
                    style: TextStyle(color: Colors.white, fontSize: 16.0),
                    iconEnabledColor: Colors.black,
                    dropdownColor: Color.fromARGB(255, 155, 190, 251),
                    underline: Container(
                      height: 2,
                      color: Colors.black,
                    ),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.0),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Vibration.vibrate(duration: 50);
                      setState(() {
                        if (item.quantity > 0) {
                          item.quantity -= 1.0;
                        }
                        if (item.quantity == 0) {
                          _groceryList.remove(item);
                        }
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.remove,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Open Sans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Vibration.vibrate(duration: 50);
                      setState(() {
                        item.quantity += 1.0;
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.0),
                  Transform.scale(
                    scale: 1.5,
                    child: Checkbox(
                      value: item.purchased,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          item.purchased = value ?? false;
                          _isChecked = item.purchased;
                          if (item.purchased) {
                            _previousList.add(GroceryItem(
                              name: item.name,
                              category: item.category,
                              purchased: true,
                            ));
                          }
                        });
                      },
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousListItem(GroceryItem item) {
    final quantityText = _formattedQuantity(item.quantity);
    _savePreviousList();
    return ListTile(
      title: Text(item.name),
      subtitle: Text('added $quantityText times'),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  bool isImperial = false;

  Widget buildRecipesPage(BuildContext context) {
    final deviceLocale = WidgetsBinding.instance!.platformDispatcher.locale;

    return Scaffold(
      body: _buildRecipesPage(deviceLocale),
    );
  }

  late Recipe _recipe;

  Widget _buildRecipesPage(Locale deviceLocale) {
    return FutureBuilder(
      future: loadRecipes(isImperial, deviceLocale.languageCode),
      builder: (BuildContext context,
          AsyncSnapshot<Map<String, List<Recipe>>> snapshot) {
        var recipesByCuisine = snapshot.data!;
        String selectedCuisine = recipesByCuisine.keys.first;
        int currentPageIndex = 0;
        final pageController = PageController(initialPage: currentPageIndex);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Icon(Icons.restaurant_menu),
                    SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.recipes,
                    ),
                  ],
                ),
                backgroundColor: Color(0xFF00BF63),
                actions: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          color: Colors.blue,
                        ),
                        child: Text(
                          isImperial
                              ? AppLocalizations.of(context)!.imperial
                              : AppLocalizations.of(context)!.metric,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Switch(
                        value: isImperial,
                        onChanged: (value) {
                          print('Loading Imperial CSV}');
                          setState(() {
                            isImperial = value;
                          });
                          loadRecipes(isImperial, deviceLocale.languageCode)
                              .then((newRecipes) {
                            setState(() {
                              recipesByCuisine = newRecipes;
                              selectedCuisine = recipesByCuisine.keys.first;
                              currentPageIndex = 0;
                              pageController.jumpToPage(currentPageIndex);
                            });
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
              body: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 8.0),
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Text(
                                AppLocalizations.of(context)!.changeCuisine,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.0),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(top: 16.0),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 2,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            isExpanded:
                                true, // Added this line to expand the dropdown
                            value: selectedCuisine,
                            iconSize: 24,
                            icon: const Icon(Icons.arrow_drop_down),
                            iconEnabledColor: Colors.black,
                            underline: Container(
                              height: 0,
                              color: Colors.transparent,
                            ),
                            onChanged: (value) {
                              setState(() {
                                selectedCuisine = value!;
                              });
                            },
                            hint: Text(
                              'Select a cuisine',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            items: recipesByCuisine.keys.map((cuisine) {
                              return DropdownMenuItem(
                                value: cuisine,
                                child: Text(
                                  cuisine,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Open Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          recipesByCuisine[selectedCuisine]!.length, (index) {
                        return Container(
                          width: 10.0,
                          height: 10.0,
                          margin: EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentPageIndex == index
                                ? Colors.black
                                : Colors.grey.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: pageController,
                      onPageChanged: (index) {
                        setState(() {
                          currentPageIndex = index;
                        });
                      },
                      itemCount: recipesByCuisine[selectedCuisine]!.length,
                      itemBuilder: (context, index) {
                        final recipe =
                            recipesByCuisine[selectedCuisine]![index];
                        return _buildRecipeListItem(recipe, () {
                          final groceryItemsToAdd = <GroceryItem>[];
                          for (final ingredient in recipe.ingredients) {
                            final groceryItem = GroceryItem(
                              name: ingredient.name,
                              category: '',
                              quantity: 1,
                              purchased: false,
                              unit: ingredient.unit,
                            );
                            groceryItemsToAdd.add(groceryItem);
                          }
                          setState(() {
                            _groceryList.addAll(groceryItemsToAdd);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.added +
                                    ' ${groceryItemsToAdd.length}' +
                                    AppLocalizations.of(context)!
                                        .ingredientsToGroceryList,
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(top: 80.0),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 30.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecipeListItem(
    Recipe recipe,
    VoidCallback onAddToGroceryList,
  ) {
    final ingredientTextStyle = TextStyle(
      fontSize: 18.0,
      color: Color(0xFF36454F),
      fontWeight: FontWeight.w400,
      fontFamily: 'Open Sans',
    );
    final quantityTextStyle = TextStyle(
      fontSize: 18.0,
      color: Color(0xFF36454F),
      fontWeight: FontWeight.w300,
      fontFamily: 'Open Sans',
    );

    final SizedBox verticalSpace = const SizedBox(height: 16.0);

    bool showAllIngredients = false;

    return StatefulBuilder(
      builder: (context, setState) {
        int selectedServings = recipe.servings;

        List<Ingredient> displayedIngredients = showAllIngredients
            ? recipe.getAdjustedIngredients()
            : recipe.getAdjustedIngredients().take(2).toList();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              style: const TextStyle(
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Open Sans',
                              ),
                            ),
                            verticalSpace,
                            Text(
                              recipe.cuisine,
                              style: const TextStyle(
                                fontSize: 18.0,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Vibration.vibrate(duration: 50);
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.0),
                                child: Container(
                                  width: 300.0,
                                  height: 300.0,
                                  child: InteractiveViewer(
                                    child: Image.asset(
                                      recipe.foodimage,
                                    ),
                                    boundaryMargin: EdgeInsets.all(20.0),
                                    minScale: 0.1,
                                    maxScale: 5.0,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: SizedBox(
                            width: 125.0,
                            height: 125.0,
                            child: Image.asset(
                              recipe.foodimage,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.servings + '    ',
                              style: ingredientTextStyle.copyWith(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Open Sans',
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.green,
                              size: 22.0,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.0),
                          color: Colors.grey[200],
                        ),
                        child: ServingsSelector(
                          initialValue: recipe.servings,
                          onValueChanged: (value) {
                            setState(() {
                              recipe.servings = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  verticalSpace,
                  Center(
                    child: DataTable(
                      columnSpacing: 16.0,
                      columns: [
                        DataColumn(
                          label: Text(
                            'Ingredients',
                            style: ingredientTextStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            AppLocalizations.of(context)!.quantity,
                            style: quantityTextStyle,
                          ),
                        ),
                      ],
                      rows: displayedIngredients.map((ingredient) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                ingredient.name,
                                style: ingredientTextStyle,
                              ),
                            ),
                            DataCell(
                              Text(
                                _formattedQuantity(ingredient.quantity) +
                                    ' ' +
                                    ingredient.unit,
                                style: quantityTextStyle,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  if (recipe.getAdjustedIngredients().length > 2)
                    Center(
                      child: InkWell(
                        onTap: () {
                          Vibration.vibrate(duration: 50);
                          setState(() {
                            showAllIngredients = !showAllIngredients;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 15.0),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.green,
                                size: 16.0,
                              ),
                              Text(
                                showAllIngredients
                                    ? 'Show less ingredients'
                                    : 'Show more ingredients',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Color(0xFF00BF63),
                          onPrimary: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        onPressed: () {
                          Vibration.vibrate(duration: 50);
                          final groceryItemsToAdd =
                              recipe.getAdjustedIngredients().map((ingredient) {
                            return GroceryItem(
                              name: ingredient.name,
                              category: '',
                              quantity: ingredient.quantity *
                                  selectedServings /
                                  recipe.servings,
                              purchased: false,
                              unit: ingredient.unit,
                              fromRecipe: true,
                            );
                          }).toList();

                          setState(() {
                            _groceryList.addAll(groceryItemsToAdd);
                            _saveGroceryList();
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.added +
                                    ' ${groceryItemsToAdd.length}' +
                                    AppLocalizations.of(context)!
                                        .ingredientsToGroceryList,
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(top: 80.0),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)!.addToGroceryList,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Open Sans',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Colors.blueAccent,
                          onPrimary: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        onPressed: () {
                          Vibration.vibrate(duration: 50);
                          recipeadcounter++;
                          _showaddonrecipebutton();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeStepsPage(recipe: recipe),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)!.viewRecipe,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Open Sans',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formattedQuantity(double quantity) {
    final fraction = Fraction.fromDouble(quantity);
    String formattedQuantity;
    if (fraction.denominator == 1) {
      formattedQuantity = fraction.numerator.toString();
    } else if (fraction.numerator > fraction.denominator) {
      final whole = fraction.numerator ~/ fraction.denominator;
      final remainder = fraction - Fraction(whole);
      formattedQuantity =
          '$whole ${remainder.numerator}/${remainder.denominator}';
    } else if (quantity - quantity.floor() > 0) {
      formattedQuantity = '$fraction';
    } else {
      formattedQuantity = quantity.toInt().toString();
    }

    if (formattedQuantity.endsWith('.00')) {
      formattedQuantity = formattedQuantity.replaceAll('.00', '');
    }
    return '$formattedQuantity';
  }

  int _selectedIndex = 0;
}
