import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rfid_hackaton/models/my_user.dart';
import 'package:rfid_hackaton/views/profile/edit_profile_page.dart';
import 'package:rfid_hackaton/views/profile/utils/user_preferences.dart';
import 'package:rfid_hackaton/views/profile/widgets/appbar_widget.dart';
import 'package:rfid_hackaton/views/profile/widgets/numbers_widget.dart';
import 'package:rfid_hackaton/views/profile/widgets/profile_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

String _userid = '';

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _getUID(),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            final user = UserPreferences.user;

            return Scaffold(
                appBar: buildAppBar(context),
                body: ListView(
                  physics: BouncingScrollPhysics(),
                  children: [
                    ProfileWidget(
                        imagePath: user.imagePath!,
                        onClicked: () {
                          Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => EditProfilePage())
                          );
                        }
                    ),
                    const SizedBox(height: 24),
                    buildName(user),
                    NumbersWidget(),
                  ],
                )
            );// your widget
        } else return CircularProgressIndicator();
        });

  }
}
Widget buildName(MyUser user) => Column(
  children: [
    Text(
      user.name!,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
    ),
    const SizedBox(height: 4),
    Text(
      user.email!,
      style: TextStyle(color: Colors.grey),
    )
  ],
);

Future<String> _getUID() async {
  final prefs = await SharedPreferences.getInstance();
  _userid = prefs.getString('uid') ?? '';
  return _userid;
}