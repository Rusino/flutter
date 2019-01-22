// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'about.dart';
import 'login.dart';

const double _kItemHeight = 48.0;
const EdgeInsetsDirectional _kItemPadding = EdgeInsetsDirectional.only(start: 56.0);

void main() => runApp(ShaperView());
//void main() => runApp(const Center(child: Text('Hello, world!', textDirection: TextDirection.ltr)));

class _OptionsItem extends StatelessWidget {
  const _OptionsItem({ Key key, this.child }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double textScaleFactor = MediaQuery.textScaleFactorOf(context);

    return MergeSemantics(
      child: Container(
        constraints: BoxConstraints(minHeight: _kItemHeight * textScaleFactor),
        padding: _kItemPadding,
        alignment: AlignmentDirectional.centerStart,
        child: DefaultTextStyle(
          style: DefaultTextStyle.of(context).style,
          maxLines: 2,
          overflow: TextOverflow.fade,
          child: IconTheme(
            data: Theme.of(context).primaryIconTheme,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem(this.text, this.onTap);

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OptionsItem(
      child: _FlatButton(
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  const _FlatButton({ Key key, this.onPressed, this.child }) : super(key: key);

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DefaultTextStyle(
        style: Theme.of(context).primaryTextTheme.subhead,
        child: child,
      ),
    );
  }
}

class ShaperView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shaper View',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shaper'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
            //_ActionItem('About Flutter Gallery', () { showGalleryAboutDialog(context);}),
            IconButton(
              icon: const Icon(Icons.search, semanticLabel: 'login'),
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (BuildContext context) => LoginPage()),
                );
              },
            ),
      ]),
      /*
      body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Default text style! ',
                children: <TextSpan>[
                  TextSpan(text: '.SF UI Text 16 yellow on gray, 500 italic, underline dashed. ',
                      style: TextStyle(
                        color: Colors.yellow,
                        background: Paint()..color = Colors.grey,
                        fontFamily: '.SF UI Text',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dashed,
                      )
                  ),
                  TextSpan(text: 'Raleway 8, orange, dotted underline. ',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontFamily: 'Raleway',
                          fontSize: 8,
                          fontWeight: FontWeight.normal,
                          fontStyle: FontStyle.normal,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                      )
                  ),
                  TextSpan(text: 'GoogleSans 12 red on light gray, bold italic, underline. ',
                      style: TextStyle(
                          color: Colors.red,
                          background: Paint()..color = Colors.black12,
                          fontFamily: 'GoogleSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.underline
                      )
                  ),
                  TextSpan(text: 'Raleway 24, purple, green wavy underline. ',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontFamily: 'Raleway',
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                        fontStyle: FontStyle.normal,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.wavy,
                        decorationColor: Colors.green
                      )
                  ),
                  TextSpan(text: 'Raleway 12, amber. ',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontFamily: 'Raleway',
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        fontStyle: FontStyle.normal,
                      )
                  ),
                  TextSpan(text: 'GoogleSans 100 green normal, 12. ', style: const TextStyle(color: Colors.green, fontFamily: 'GoogleSans', fontSize: 12, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal)),
                  TextSpan(text: 'monospace 900 20, blue, italic, line through.',
                      style: const TextStyle(
                          color: Colors.blue,
                          fontFamily: 'monospace',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.lineThrough
                      )
                  ),
                  TextSpan(text: 'Text with a shadow.', style: const TextStyle(
                    shadows: <Shadow>[
                      Shadow(
                        offset: Offset(10.0, 10.0),
                        blurRadius: 3.0,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                      Shadow(
                        offset: Offset(10.0, 10.0),
                        blurRadius: 8.0,
                        color: Color.fromARGB(125, 0, 0, 255),
                      ),
                    ],
                  )),
                ]
              )
            )
          ),
          Expanded(
                child: Text(
                  'All courses of action are risky, so prudence is not in avoiding danger (it\'s impossible), but calculating risk and acting decisively. Make mistakes of ambition and not mistakes of sloth. Develop the strength to do bold things, not the strength to suffer.',
                  style: const TextStyle(fontSize: 17.0)
            ),
          ),
          Expanded(
                child: Text(
                  'People should either be caressed or crushed. If you do them minor damage they will get their revenge; but if you cripple them there is nothing they can do. If you need to injure someone, do it in such a way that you do not have to fear their vengeance.',
                  style: const TextStyle(fontSize: 17.0)
            ),
          ),
        ],
      ),
      */
    );
  }
}


