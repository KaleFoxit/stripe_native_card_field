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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

  // Creating a global key here allows us to call the `getStripeResponse()`
  // inside the CardTextFieldState widget in our build method. See below
  final _key = GlobalKey<CardTextFieldState>();

  @override
  Widget build(BuildContext context) {
    final cardField = CardTextField(
      key: _key,
      loadingWidgetLocation: LoadingLocation.above,
      stripePublishableKey: 'pk_test_abc123testmykey',
      width: 600,
      onValidCardDetails: (details) {
        if (kDebugMode) {
          print(details);
        }
      },
      overrideValidState: state,
      errorText: errorText,
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Enter your card details below:',
              ),
            ),
            cardField,
            ElevatedButton(
              child: const Text('Set manual error'),
              onPressed: () => setState(() {
                errorText = 'There is a problem';
                state = CardDetailsValidState.invalidCard;
              }),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              child: const Text('Get Stripe token'),
              onPressed: () async {
                // Here we use the global key to get the stripe data, rather than
                // using the `onStripeResponse` callback in the widget
                final tok = await _key.currentState?.getStripeResponse();
                if (kDebugMode) print(tok);
              },
            )
          ],
        ),
      ),
    );
  }
}
