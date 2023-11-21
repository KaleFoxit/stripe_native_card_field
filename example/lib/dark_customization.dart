
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stripe_native_card_field/card_details.dart';
import 'package:stripe_native_card_field/stripe_native_card_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Native Stripe Field Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CardDetailsValidState? state;
  String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black45,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Enter your card details below:',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            CardTextField(
              width: 300,
              onCardDetailsComplete: (details) {
                if (kDebugMode) {
                  print(details);
                }
              },
              textStyle: TextStyle(fontFamily: 'Lato', color: Colors.tealAccent),
              hintTextStyle: TextStyle(fontFamily: 'Lato', color: Colors.teal),
              errorTextStyle: TextStyle(color: Colors.purpleAccent),
              boxDecoration: BoxDecoration(
                color: Colors.black54,
                border: Border.all(
                  color: Colors.teal.withAlpha(255),
                ),
              ),
              errorBoxDecoration: BoxDecoration(
                color: Colors.black54,
                border: Border.all(width: 3.0, color: Colors.purple),
              ),
              cardIconColor: 'teal',
              cardIconErrorColor: '#b65cc2',
              overrideValidState: state,
              errorText: errorText,
            ),
            ElevatedButton(
              child: const Text('Set manual error'),
              onPressed: () => setState(() {
                errorText = 'There is a problem';
                state = CardDetailsValidState.invalidCard;
              }),
            )
          ],
        ),
      ),
    );
  }
}
