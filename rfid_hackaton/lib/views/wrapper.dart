import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rfid_hackaton/models/my_user.dart';
import 'package:rfid_hackaton/views/authenticate/authenticate.dart';
import 'package:rfid_hackaton/views/company/realtime_dashboard.dart';
import 'package:rfid_hackaton/views/home/home.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final user = Provider.of<MyUser?>(context);

    print( "User in WRAPPER: " + user.toString());

    if (user == null){
      return Authenticate();
    } else {
      if (user.isBusCompany == true){
        return  const RealtimeDashboard(title: 'Realtime Dashboard', showAppBar: false,);
      } else {
        return const Home(title: 'RFID Bus Tracker');
      }
    }
    // return Home o Authenticate, depenent si està logejat

    return Authenticate();
    // return Home(title: 'RFID Bus Tracker') ;
  }
}
