import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rfid_hackaton/models/bus_stop.dart';
import 'package:rfid_hackaton/models/my_user.dart';
import 'package:rfid_hackaton/views/favourites/favorites_dialog.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../models/bus_real_data.dart';
import '../services/gps_service.dart';
import '../services/map_service.dart';
import '../services/realtime_database.dart';

class BusView extends StatefulWidget {
  const BusView({Key? key, required this.title, required this.isClient, this.isFavorite, this.polylines,  this.markers, this.origin, this.destination, this.linesToUse, this.busStops, this.user}) : super(key: key);

  final String title;

  final BusStop? origin;
  final BusStop? destination;

  final MyUser? user;

  final List<String>? linesToUse;
  final Map<PolylineId, Polyline>? polylines;
  final Map<MarkerId, Marker>? markers;

  final bool isClient;
  final bool? isFavorite;

  final Map<String, BusStop>? busStops;


  @override
  State<BusView> createState() => _BusViewState();
}

class _BusViewState extends State<BusView> {
  late RealDatabaseService _dbref;

  Map<int, BusRtData> busRealTimeData = <int, BusRtData>{};

  final Map<String, List<BusStop>>? routes = <String, List<BusStop>>{};

  final Completer<GoogleMapController> _controller = Completer();

  final PanelController _pc = PanelController();

  int _currentBusIndex = 0;

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  Map<PolylineId, Polyline> polylines = <PolylineId, Polyline>{};

  bool busesSpawned = false;
  bool  _isMapCreated = false;
  bool _followBus = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// It hides the panel for some seconds so the user can see the map
  /// and then it shows the panel again

  Future<void> showMarkerAnimation(GoogleMapController controller, String query) async {
    _pc.close();

    // hide keyboard
    FocusScope.of(context).requestFocus(FocusNode());

    // wait for 1 second
    await Future.delayed(const Duration(seconds: 3));
    // then move to the marker
    LatLng latLng = widget.markers![MarkerId(query)]!.position;

    LatLng  offsetLoc = LatLng(latLng.latitude - 0.010, latLng.longitude);

    controller.animateCamera(CameraUpdate.newLatLngZoom(offsetLoc, 14.4746));
    // wait for 1 second
    _pc.open();
  }

  /// This function is called when the user writes a query.
  /// It will call the Google Maps API to get the coordinates of the query.
  /// It will then call the generateMarker function to add a marker to the map.
  /// Finally, it will call the showMarkerAnimation function to animate the camera to the marker.
  /// This function is called when the user writes a query.
  Future<void> moveToPossibleBusLocation(int busId, {double zoom = 14.4746}) async {
    if (busRealTimeData != null && busRealTimeData.isNotEmpty) {
      // get the bus location
      BusRtData busRtData = busRealTimeData[busId]!;

      LatLng busPosition = LatLng(busRtData.busLineLatitude, busRtData.busLineLongitude);

      final GoogleMapController controller = await _controller.future;

      try {
        final cameraUpdate = CameraUpdate.newCameraPosition(CameraPosition(
          target: busPosition,
          zoom: zoom,
        ));

        controller.animateCamera(cameraUpdate);

      } catch (e) {
        MapService().showAlertDialog(context,  'No location found for');
      }
    }
    else{
      MapService().showAlertDialog(context,  'No buses are available yet!');
    }

  }

  double circularRadius = 10;

  void fillBusRealTimeData(dynamic buses) {
    int i = 0;
    for (var bus in buses.values) {
      // convert to json
      var busJson = json.encode(bus);
      print(busJson);
      final parsedJson = jsonDecode(busJson);
      BusRtData busData = BusRtData.fromJson(parsedJson);

      if (widget.linesToUse != null) {
        if (widget.linesToUse!.contains(busData.busLineId)) {  // if the bus is on the line we want to see
          busRealTimeData[i] = busData;
          i++;
        }
      } else {
        busRealTimeData[i] = busData;
        i++;
      }

    }
  }

  void generatePolylines(){
    if (widget.busStops != null && busRealTimeData != null && busRealTimeData.isNotEmpty) {
      for (var busLine in busRealTimeData.values) {
        if (routes![busLine.busLineId] == null) {
          routes![busLine.busLineId] = <BusStop>[];
        }

        for (var busStop in widget.busStops!.values) {
          if (busLine.busLineRoute.contains(busStop.stopId)) {
            routes![busLine.busLineId]!.add(busStop);

            InfoWindow infoWindow = InfoWindow(
              title: busStop.stopName,
              snippet: busStop.stopId,
            );

            MapService().generateMarker(busStop.stopId, infoWindow,  busStop.stopLatitude, busStop.stopLongitude, MarkerType.busStop, markers);
          }
        }
      }

      for (String route in routes!.keys) {
        List<BusStop> busStops = routes![route]!;

        // create a list of lat longs for the polyline to be drawn from the bus stops

        List<LatLng> polylinePoints = <LatLng>[];

        for (BusStop busStop in busStops) {
          polylinePoints.add(LatLng(busStop.stopLatitude, busStop.stopLongitude));
        }

        MapService().createPolyLine(polylinePoints, polylines);
      }

    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    if(widget.markers != null){
      widget.markers!.forEach((key, value) {
        markers[key] = value;
      });
    }

    if (widget.polylines != null) {
      widget.polylines!.forEach((key, value) {
        polylines[key] = value;
      });
    }

    _dbref = RealDatabaseService();

    _dbref
        .getBusesData()
        .onValue
        .listen((event) {
      setState(() {
        dynamic buses = event.snapshot.value;

        if (buses != null) {
          fillBusRealTimeData(buses);
        }

      });
    });

    _dbref.getBusesData().get().then((buses) {
      if (buses != null) {
          int i = 0;

          for (var bus in buses.value.values)
          {
            // convert to json
            var busJson = json.encode(bus);
            print(busJson);

            final parsedJson = jsonDecode(busJson);
            BusRtData busData = BusRtData.fromJson(parsedJson);

            busRealTimeData[i] = busData;

          }
          //generatePolylines();
        }
    });


  }

  @override
  Widget build(BuildContext context) {

    BorderRadiusGeometry radius = BorderRadius.only(
      topLeft: Radius.circular(circularRadius),
      topRight: Radius.circular(circularRadius),
    );

    Widget fab = FloatingActionButton(
      onPressed: () {
        MapService().updateMapLocation(() { setState(() {}); }, context, null, _controller, markers);
      },
      child: const Icon(Icons.my_location),
    );

    if (widget.isClient && widget.user != null && widget.isFavorite! == false) {
        fab = FavoritesDialog(user: widget.user!, origin: widget.origin!, destination: widget.destination!, scaffoldKey: _scaffoldKey);
    }


    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: ()=>{
              setState(() {
                _followBus = !_followBus;
              }),
            },
            child: Text(_followBus ? 'Unfollow Bus' : 'Follow Bus'),
          ),
        ],
      ),
      body: SlidingUpPanel(
          renderPanelSheet: false,
          borderRadius:  radius,
          collapsed: buildTopPartCollapsed(),
          panel: buildTopPart(),
          body: buildBody(context),
          slideDirection: SlideDirection.DOWN,
          minHeight: MediaQuery.of(context).size.height * 0.15,
          maxHeight: MediaQuery.of(context).size.height * 0.25,
        ),
      floatingActionButton: fab,
    );

  }

  void buildFromTo(List<Widget> children) {
    children.add(
      Center(
        child: Text(
          'BUS: ${busRealTimeData[_currentBusIndex]?.busLineName}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );

    children.add(
        const Divider(
          color: Colors.orange,
          thickness: 1,
        )
    );

    children.add(
      Text(
        'From: ${widget.origin!.stopName}',
        style: const TextStyle(fontSize: 20),
      ),
    );

    children.add(
      Text(
        'To: ${widget.destination!.stopName}',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }

  void buildDataText(List<Widget> children, { bool fullInfo = false }) {

    children.add(
      Center(
        child: Text(
          'BUS: ${busRealTimeData[_currentBusIndex]?.busLineName}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );

    children.add(
        const Divider(
          color: Colors.orange,
          thickness: 1,
        )
    );

    children.add(
      Text(
        "Current Stop: ${busRealTimeData[_currentBusIndex]?.busLineCurrentStop.stopName}",
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.orange,
        ),
      ),
    );

    children.add(
      Text(
        "Next Stop: ${busRealTimeData[_currentBusIndex]?.busLineNextStop.stopName}",
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.orange,
        ),
      )
    );

    if (fullInfo == true && !widget.isClient) {
      children.add(
        Text(
          "Lat ${busRealTimeData[_currentBusIndex]?.busLineLatitude} Lon ${busRealTimeData[_currentBusIndex]?.busLineLongitude}",
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.orange,
          ),
        )
      );

      children.add(
          Text(
              "Bus Line Id: ${busRealTimeData[_currentBusIndex]?.busLineId}",
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          )
      );

      children.add(
          Text("Bus next time: ${busRealTimeData[_currentBusIndex]?.busLineNextBusTime}",
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          )
      );
    }
  }

  Widget buildTopPartCollapsed() {
    List<Widget> children  = <Widget>[];

    if (widget.origin != null && widget.destination != null) {
      buildFromTo(children);
    }else{
      buildDataText(children);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 1.2,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(circularRadius),
          bottomRight: Radius.circular(circularRadius),
        ),
      ),
      child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          )),
    );
  }

  Widget buildTopPart() {

    List<Widget> children  = <Widget>[];

    buildDataText(children, fullInfo: true);

    if (widget.origin != null && widget.destination != null && widget.isClient) {
      buildFromTo(children);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 1.2,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(circularRadius),
          bottomRight: Radius.circular(circularRadius),
        ),
      ),
      child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          )),
    );
  }

  Widget buildBody(BuildContext context) {

    LatLng? destination = LatLng(0,0);
    LatLng? origin = LatLng(0,0);

    if (widget.destination != null || widget.origin != null) {
      destination = LatLng(widget.destination!.stopLatitude, widget.destination!.stopLongitude);
      origin = LatLng(widget.origin!.stopLatitude, widget.origin!.stopLongitude);
    }

    return Stack(
      children:
      [
        buildGoogleMaps(context, destination, origin),
        Positioned(
          bottom:  MediaQuery.of(context).size.height * 0.1,
          child: buildBottomSheet(),
        ),
      ],
    );
  }

  /// Builds the google maps widget
  Widget buildGoogleMaps(BuildContext context , LatLng? destination, LatLng? origin) {

    CameraPosition cameraPosition = CameraPosition(
      target: origin ?? const LatLng(37.42796133580664, -122.085749655962),
      zoom: 14.4746,
    );


    if (_isMapCreated) {

      for (var busData in busRealTimeData.values) {

        // updates the bus markers on the map

        InfoWindow infoWindow  = InfoWindow(
          title: busData.busLineName,
          snippet: '${busData.busLinePeopleNumber}',
        );

        MapService().generateMarker(
            busData.busLineId, infoWindow, busData.busLineLatitude,
            busData.busLineLongitude, MarkerType.bus, markers);


        // Updates the bus stops markers on the map

        if (busData.busLineCurrentStop != null && markers[busData.busLineCurrentStop.stopId] != null) {

          InfoWindow infoWindow  = InfoWindow(
            title: busData.busLineName,
            snippet: '${busData.busLinePeopleNumber}',
          );

          MapService().generateMarker(
              busData.busLineCurrentStop.stopId,
              infoWindow,
              busData.busLineCurrentStop.stopLatitude,
              busData.busLineCurrentStop.stopLongitude,
              MarkerType.busStop, markers);
        }

      }

      if (_followBus) {
        moveToPossibleBusLocation(_currentBusIndex, zoom: 15.4746);
      }
    }

    return GoogleMap(
      zoomControlsEnabled: true,
      mapType: MapType.normal,
      initialCameraPosition: cameraPosition,
      markers: Set<Marker>.of(markers.values),
      polylines: Set<Polyline>.of(polylines.values),
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
        setState(() {
          _isMapCreated = true;

          if (polylines != null && polylines.isNotEmpty) {
            Set<Polyline> polylinesSet = Set<Polyline>.of(
                polylines.values);

            MapService().zoomToPolyline(_controller, polylinesSet);
          }else{
            moveToPossibleBusLocation(_currentBusIndex);

          }
        });
      },
      onTap: (LatLng latLng) {
        MapService().showAlertDialog(context, latLng.toString());
      },
    );
  }

  Widget buildCollapsed(BorderRadiusGeometry radius, { bool isExpanded = false }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).backgroundColor,
        borderRadius: radius,
      ),
      margin: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
      height: isExpanded ? 100.0 : 200.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          if (!isExpanded)
            const Center(
              child: Icon (Icons.keyboard_arrow_up, size: 40, color: Colors.blue,),
            ),
          if (isExpanded)
            const Center(
              child: Icon (Icons.keyboard_arrow_down, size: 40, color: Colors.blue,),
            ),
          Padding(
            padding:  EdgeInsets.only(left: 16.0, right: 16.0, bottom: (!isExpanded) ?  0.0 : 16.0),
            child: const Text(
              'Available Bus Lines',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomSheet() {
    return Center(
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.all(Radius.circular(circularRadius)),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 20.0,
                  color: Colors.grey,
                ),
              ]
          ),
          width: MediaQuery.of(context).size.width*0.88,
          padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
          margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),

          child: _itemRow(context),
        ),
    );

  }

  Widget _itemRow(BuildContext context) {
    return  Row(
          children: <Widget>[
            if (busRealTimeData.length > 1)
            // button with left arrow
            TextButton(
              onPressed: ()=>{
                setState(() {
                  _currentBusIndex = (_currentBusIndex - 1).clamp(0, busRealTimeData.length - 1);
                }),
                moveToPossibleBusLocation(_currentBusIndex),
              },
              child: const Icon(Icons.arrow_back_ios, size: 25, color: Colors.blue,),
            ),
            Expanded(
              child: _itemBuilder(context, _currentBusIndex),
            ),
            if (busRealTimeData.length > 1)
            // button with right arrow
            TextButton(
              onPressed: ()=>{
                setState(() {
                  _currentBusIndex = (_currentBusIndex + 1).clamp(0, busRealTimeData.length - 1);
                }),

                moveToPossibleBusLocation(_currentBusIndex),
              },
              child: const Icon(Icons.arrow_forward_ios, size: 25, color: Colors.blue,),
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceEvenly ,
          crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    if (busRealTimeData.isEmpty) {
      return const Center(
        child: Text('No buses found'),
      );
    }

    if (index >= busRealTimeData.length) {
      return const Center(
        child: Text('No buses found'),
      );
    }

    return Column(
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      children: [
                        const WidgetSpan(
                          child: Icon(Icons.emoji_people_outlined , size: 30),
                        ),
                        TextSpan(
                          text:  busRealTimeData[index]!.busLinePeopleNumber.toString(),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        const WidgetSpan(
                          child: Icon(Icons.timelapse, size: 30),
                        ),
                        TextSpan(
                          text: "Next Bus: ${busRealTimeData[index]!.busLineNextBusTime}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,

    );
  }

}
