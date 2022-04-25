import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'authentication.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import 'dart:io';

/* --------------------------- App main frame start ------------------------- */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}


class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  App({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
                body: Center(
                    child: Text(snapshot.error.toString(),
                        textDirection: TextDirection.ltr)
                )
            )
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (context) => AuthRepository.instance()),
                ChangeNotifierProxyProvider<AuthRepository, WordNotifier>(
                    create: (context) => WordNotifier(),
                    update: (context, auth, notifier) => notifier!.update(auth),
                ),
              ],
            child: const MyApp(),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter EX3 App',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const RandomWords(),
    );
  }
}
/* ---------------------------- App main frame end -------------------------- */

/* ------------------------- Word Notifier Class start ---------------------- */

class WordNotifier extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthRepository? _authRepo;
  final _suggestions = <WordPair>[];
  final _saved = <WordPair>{};
  get saved => _saved;

  void removePair(WordPair name) {
    _saved.remove(name);
    _updateDB(name);
    notifyListeners();
  }

  Future getDoc(String? docID) async {
    var a = await _firestore.collection("users").doc(docID).get();
    if(a.exists){
      return a;
    }
    if(!a.exists){
      return null;
    }
  }

  void _getFromDB(AuthRepository authRepo) async {
    if (authRepo.isAuthenticated) {
      var cloudDoc = await getDoc(authRepo.user!.email);
      if (cloudDoc == null) {
        _firestore.collection("users").doc(authRepo.user!.email).set({"favorites": []});
      } else {
        var action =  _firestore.collection("users").doc(authRepo.user!.email).get().then((value) {
          var data = value.data();
          var savedInDB = data==null?{}:data["favorites"];
          var wordsSet = {...List<String>.from(savedInDB)};
          var regularExpr = RegExp(r"(?<=[a-z])(?=[A-Z])");
          var toAdd = wordsSet.map((e) => WordPair(e.split(regularExpr)[0].toLowerCase(),e.split(regularExpr)[1].toLowerCase()));
          _saved.addAll(toAdd);
        }).then((value) {notifyListeners();});
      }
    }
  }

  void _updateDB(WordPair? remove){
    if (_authRepo == null) return;
    if (_authRepo!.isAuthenticated) {
      if (remove == null) {
        var newList = _saved.map((e) => e.asPascalCase).toList();
        var action = _firestore.collection("users").doc(_authRepo!.user!.email).update({"favorites":FieldValue.arrayUnion(newList)}).then((value) {});
      } else {
        var action = _firestore.collection("users").doc(_authRepo!.user!.email).update({"favorites":FieldValue.arrayRemove([remove.asPascalCase])}).then((value) {});
      }
    }
  }

  WordNotifier update(AuthRepository auth) {

    _getFromDB(auth);
    _authRepo = auth;
    _updateDB(null);
    return this;
  }

  Widget _buildRow(WordPair pair, AuthRepository authentication) {
    final alreadySaved = _saved.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: const TextStyle(fontSize: 18),
      ),
      trailing: Icon(
        alreadySaved ? Icons.star : Icons.star_border,
        color: alreadySaved ? Colors.deepPurple : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () {
        if (alreadySaved) {
          _saved.remove(pair);
          _updateDB(pair);
        } else {
          _saved.add(pair);
          _updateDB(null);
        }
        notifyListeners();
      },
    );
  }

  Widget buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.all(7),
      itemBuilder: (context, i) {
        if (i.isOdd) {
          return const Divider();
        }
        final index = i ~/ 2;
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10));
        }
        return _buildRow(_suggestions[index], Provider.of<AuthRepository>(context, listen: false));
      },
    );
  }
}
/* ------------------------- Word Notifier Class end ------------------------ */

/* ------------------------- RandomWords Class start ------------------------ */

class RandomWords extends StatelessWidget {
  const RandomWords({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthRepository,WordNotifier>(
      builder: (context, authRepo, randomWords, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Flutter EX3 App'),
            actions: [
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () {
                  _pushSaved(context);
                },
                tooltip: 'Saved Suggestions',
              ),
              IconButton(
                icon: authRepo.isAuthenticated
                    ? const Icon(Icons.exit_to_app)
                    : const Icon(Icons.login),
                onPressed: () {
                  if (authRepo.isAuthenticated) {
                    randomWords._saved.clear();
                    _pushLogout(context, authRepo);
                  } else {
                    _pushLogin(context);
                  }
                },
                tooltip: authRepo.isAuthenticated ? 'Logout' : 'Login',
              ),
            ],
          ),
          body: authRepo.isAuthenticated? const SimpleSnappingSheet() : randomWords.buildSuggestions(),
        );
      },
    );
  }

  void _pushLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return UserLogin();
        },
      ),
    );
  }

  void _pushLogout(BuildContext context, AuthRepository authentication) async {
    await authentication.signOut();
  }

  void _pushSaved(BuildContext context) {
    final saved = Provider.of<WordNotifier>(context, listen: false).saved;
    final tiles = saved.map<Widget>(
          (pair) {
        return Dismissible(
          child: ListTile(
            title: Text(
              pair.asPascalCase,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          key: ValueKey<WordPair>(pair),
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.deepPurple,
            alignment: Alignment.centerLeft,
            child: Row(
              children: const [
                Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                Text(
                  "Delete suggestion",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.deepPurple,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  "Delete suggestion",
                  style: TextStyle(color: Colors.white),
                ),
                Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          confirmDismiss: (DismissDirection direction) async {
            return await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete Suggestion'),
                  content: SingleChildScrollView(
                    child: Text('Are you sure you want to delete $pair from your saved suggestions?'),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('No'),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                    ),
                    TextButton(
                      child: const Text('Yes'),
                      onPressed: () {
                        Provider.of<WordNotifier>(context, listen: false).removePair(pair);
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    final divided = tiles.isNotEmpty ? ListTile.divideTiles(context: context, tiles: tiles,).toList() : <Widget>[];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }
}

/* --------------------------- RandomWords Class end ------------------------ */


/* --------------------------- UserLogin Class start ------------------------ */

class UserLogin extends StatelessWidget{
  UserLogin({Key? key}) : super(key: key);
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Login'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: <Widget>[
              const SizedBox(height: 15),
              const Text("Welcome to Flutter EX3 App, please log in below"),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Email'
                ),
                controller: emailController,
              ),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Password'
                ),
                controller: passwordController,
                  obscureText: true
              ),
              const SizedBox(height: 20),
              Consumer<AuthRepository>(
                builder: (context, authRepo, child){
                  return ElevatedButton(
                    onPressed: () async{
                      if (authRepo.status == Status.Authenticating) {}
                      else {
                        var res = await authRepo.signIn(emailController.text, passwordController.text);
                        if (res == true){
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('There was an error logging into the app')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      primary: authRepo.status == Status.Authenticating?Colors.black12:Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Log in"),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) { return BottomSheet(mail: emailController, password: passwordController);});
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  primary: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text("New user? Click to sign up"),
              )
            ],
          )
      ),
    );
  }
}
/* ------------------------- UserLogin Class end ---------------------------- */



/* ----------------------- BottomSheet Class start -------------------------- */

class BottomSheet extends StatefulWidget {
  var mail;
  var password;
  BottomSheet(
      {Key? key, required this.mail, required this.password})
      : super(key: key);

  @override
  _BottomSheetState createState() =>
      _BottomSheetState(mail, password);
}

class _BottomSheetState extends State<BottomSheet> {
  var mail;
  var password;
  final passwordController = TextEditingController();
  var _valid = true;

  _BottomSheetState(this.mail, this.password);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthRepository>(builder: (context, authRepo, child) {
      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            height: 200,
            child: Column(
              children: [
                const ListTile( title: Center(child: Text('Please confirm your password below:'),),),
                const Divider(),
                TextField(
                  decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _valid ? null : "Passwords must match"),
                  controller: passwordController,
                  obscureText: true,
                ),
                const Divider(),
                ElevatedButton(
                  onPressed: () {
                    if (authRepo.status == Status.Authenticating) {}
                    else {
                      if (passwordController.text == password.text) {
                        authRepo.signUp(mail.text, password.text).then(
                              (value) {
                            if (value != null) {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            } else { setState(() { _valid = true;});}
                          },
                        );
                      } else { setState(() { _valid = false;});}
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: authRepo.status == Status.Authenticating
                        ? Colors.black12
                        : Colors.lightBlue,
                  ),
                  child: const Text("Confirm"),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/* ------------------------ BottomSheet Class end --------------------------- */


/* ---------------------- SnappingSheet Class start ------------------------- */

class SimpleSnappingSheet extends StatefulWidget {
  const SimpleSnappingSheet({Key? key}) : super(key: key);

  @override
  _SimpleSnappingSheetState createState() => _SimpleSnappingSheetState();
}

class _SimpleSnappingSheetState extends State<SimpleSnappingSheet> {
  final ScrollController listViewController = ScrollController();
  var snappingController = SnappingSheetController();

  List<SnappingPosition> enabledPositions = const [
    SnappingPosition.factor(
      grabbingContentOffset: GrabbingContentOffset.bottom,
      snappingCurve: Curves.easeInExpo,
      snappingDuration: Duration(seconds: 1),
      positionFactor: 0.3,
    ),
    SnappingPosition.factor(
      grabbingContentOffset: GrabbingContentOffset.bottom,
      snappingCurve: Curves.easeInExpo,
      snappingDuration: Duration(seconds: 1),
      positionFactor: 1,
    ),
  ];
  List<SnappingPosition> disabledPositions = const [
    SnappingPosition.factor(
      grabbingContentOffset: GrabbingContentOffset.bottom,
      snappingCurve: Curves.easeInExpo,
      snappingDuration: Duration(seconds: 1),
      positionFactor: 0.1,
    ),
  ];
  bool enabled = false;

  void changeState() {
    setState(() {
      enabled = !enabled;
      snappingController.snapToPosition(
          enabled ? enabledPositions[0] : disabledPositions[0]);
    });
  }

  @override
  Widget build(BuildContext context) {
    String mail = Provider.of<AuthRepository>(context, listen: false).user!.email!;
    return SnappingSheet(
      controller: snappingController,
      child: Provider.of<WordNotifier>(context, listen: true).buildSuggestions(),
      lockOverflowDrag: true,
      snappingPositions: enabled ? enabledPositions : disabledPositions,
      grabbing: GestureDetector(
        onTap: () => changeState(),
        child: Container(
          alignment: Alignment.centerLeft,
          color: Colors.grey[400],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                child: Text(
                  "Welcome back, $mail", //auth.email
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Icon(Icons.keyboard_arrow_up),
              ),
            ],
          ),
        ),
      ),
      grabbingHeight: 55,
      sheetAbove: enabled?SnappingSheetContent(
        draggable: false,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 3.0,
              sigmaY: 3.0,
            ),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ): null,
      sheetBelow: SnappingSheetContent(
        draggable: true,
        childScrollController: listViewController,
        child: const BelowSheet(),
      ),
    );
  }
}

/* ---------------------- SnappingSheet Class end --------------------------- */


/* ----------------------- BelowSheet Class start --------------------------- */

class BelowSheet extends StatefulWidget {
  const BelowSheet({Key? key}) : super(key: key);

  @override
  _BelowSheetState createState() => _BelowSheetState();
}

class _BelowSheetState extends State<BelowSheet> {
  String mail = "";
  String avatarURL = "";
  var avatarImage = null;
  final defaultImage = const NetworkImage('https://lh3.googleusercontent.com/a-/AOh14GiT9-PUr_Yecyqe73942LBn609KL-CrpMXTgN41Gw=s432-p-no');

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image:
                    DecorationImage(image: avatarImage ?? defaultImage, fit: BoxFit.fill),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        mail,
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Center(child:SizedBox(
                      width: 130,
                      height: 30,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Colors.lightBlue,
                        ),
                        onPressed: () => _changeAvatar(),
                        child: const Text(
                          "Change avatar",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _loadImage() async {
    avatarURL = await FirebaseStorage.instance.ref('/users/$mail').getDownloadURL();
    avatarImage = NetworkImage(avatarURL);
  }

  @override
  void initState() {
    super.initState();
    mail = Provider.of<AuthRepository>(context, listen: false).user!.email!;
    _loadImage();
  }

  void _changeAvatar() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Path not found')),
      );
      return;
    }
    FirebaseStorage.instance.ref("users/$mail").putFile(File(image.path))
    .then(
        (value) async {
          avatarURL = await FirebaseStorage.instance.ref('users/$mail').getDownloadURL();
          setState(() {});
          avatarImage = NetworkImage(avatarURL);
          setState(() {});
        });
  }
}

/* ------------------------ BelowSheet Class end ---------------------------- */








