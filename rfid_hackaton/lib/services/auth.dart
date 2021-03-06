import 'package:firebase_auth/firebase_auth.dart';
import 'package:rfid_hackaton/models/my_user.dart';
import 'package:rfid_hackaton/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  // crear MyUser basat en l'usuari de Firebase
  MyUser? _userFromFirebaseUser(User user){
    return user != null ? MyUser(
        uid: user.uid, name: null, email: user.email, city: null, co2saved: null, km: null, isDarkMode: false, sex: 'Male', imagePath: null ) : null;
  }

  // Steam escoltant per Auth Changes. Cada cop que entri o surti, s'activa el listener
  // tipus usuari si entre, null si surt
  Stream<MyUser?> get user{
    return _auth.authStateChanges()
        .map((User? user) => _userFromFirebaseUser(user!));
        // .map(_userFromFirebaseUser)
  }
  
  // sign in anonymous
  Future signInAnon() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      return _userFromFirebaseUser(user!);
    } catch(e){
      print(e.toString());
      return null;
    }
  }


  // sign in email and password
  Future signInWithEmailAndPassword(String email, String passwd) async{
    try{
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: passwd);
      User? user = result.user;

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('uid',  user!.uid);

      return _userFromFirebaseUser(user);
    }catch(e){
      print(e.toString());
      return null;
    }
  }

  // register with email and password
Future registerWithEmailAndPassword(String email, String passwd, String name, String imagePath, String sex, String city) async{
    try{
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: passwd);

      print(result);

      User? user = result.user;

      await DatabaseService(userID: user!.uid).updateUserData(user.email!, name, imagePath, sex,city);

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('uid',  user.uid);

      return _userFromFirebaseUser(user);
    }catch(e){
      print(e.toString());
      return e.toString();
    }
}
  // sign out
Future signOut() async{
    try {
      return await _auth.signOut();
    }
    catch(e){
      print(e.toString());
        }
}
}