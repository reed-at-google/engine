import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/src/arg_results.dart';
import 'package:frontend_server/server.dart';
// front_end/src imports below that require lint `ignore_for_file`
// are a temporary state of things until frontend team builds better api
// that would replace api used below. This api was made private in
// an effort to discourage further use.
// ignore_for_file: implementation_imports
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/ast.dart' show Program;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm/incremental_compiler.dart';

class _MockedCompiler extends Mock implements CompilerInterface {}

class _MockedIncrementalCompiler extends Mock
  implements IncrementalCompiler {}

class _MockedBinaryPrinterFactory extends Mock implements BinaryPrinterFactory {}

class _MockedBinaryPrinter extends Mock implements BinaryPrinter {}

Future<int> main() async {
  group('basic', () {
    final CompilerInterface compiler = new _MockedCompiler();

    test('train with mocked compiler completes', () async {
      expect(await starter(<String>['--train'], compiler: compiler), equals(0));
    });
  });

  group('batch compile with mocked compiler', () {
    final CompilerInterface compiler = new _MockedCompiler();

    test('compile from command line', () async {
      final List<String> args = <String>[
        'server.dart',
        '--sdk-root',
        'sdkroot',
      ];
      final int exitcode = await starter(args, compiler: compiler);
      expect(exitcode, equals(0));
      final List<ArgResults> capturedArgs =
        verify(
          compiler.compile(
            argThat(equals('server.dart')),
            captureAny,
            generator: any,
          )
        ).captured;
      expect(capturedArgs.single['sdk-root'], equals('sdkroot'));
      expect(capturedArgs.single['strong'], equals(false));
    });

    test('compile from command line (strong mode)', () async {
      final List<String> args = <String>[
        'server.dart',
        '--sdk-root',
        'sdkroot',
        '--strong',
      ];
      final int exitcode = await starter(args, compiler: compiler);
      expect(exitcode, equals(0));
      final List<ArgResults> capturedArgs =
        verify(
          compiler.compile(
            argThat(equals('server.dart')),
            captureAny,
            generator: any,
          )
        ).captured;
      expect(capturedArgs.single['sdk-root'], equals('sdkroot'));
      expect(capturedArgs.single['strong'], equals(true));
    });

    test('compile from command line with link platform', () async {
      final List<String> args = <String>[
        'server.dart',
        '--sdk-root',
        'sdkroot',
        '--link-platform',
      ];
      final int exitcode = await starter(args, compiler: compiler);
      expect(exitcode, equals(0));
      final List<ArgResults> capturedArgs =
          verify(
              compiler.compile(
                argThat(equals('server.dart')),
                captureAny,
                generator: any,
              )
          ).captured;
      expect(capturedArgs.single['sdk-root'], equals('sdkroot'));
      expect(capturedArgs.single['link-platform'], equals(true));
      expect(capturedArgs.single['strong'], equals(false));
    });
  });

  group('interactive compile with mocked compiler', () {
    final CompilerInterface compiler = new _MockedCompiler();

    final List<String> args = <String>[
      '--sdk-root',
      'sdkroot',
    ];

    test('compile one file', () async {
      final StreamController<List<int>> inputStreamController =
      new StreamController<List<int>>();
      final ReceivePort compileCalled = new ReceivePort();
      when(compiler.compile(any, any, generator: any)).thenAnswer(
              (Invocation invocation) {
            expect(invocation.positionalArguments[0], equals('server.dart'));
            expect(invocation.positionalArguments[1]['sdk-root'],
                equals('sdkroot'));
            expect(invocation.positionalArguments[1]['strong'], equals(false));
            compileCalled.sendPort.send(true);
          }
      );

      final int exitcode = await starter(args, compiler: compiler,
        input: inputStreamController.stream,
      );
      expect(exitcode, equals(0));
      inputStreamController.add('compile server.dart\n'.codeUnits);
      await compileCalled.first;
      inputStreamController.close();
    });
  });

  group('interactive compile with mocked compiler', () {
    final CompilerInterface compiler = new _MockedCompiler();

    final List<String> args = <String>[
      '--sdk-root',
      'sdkroot',
    ];
    final List<String> strongArgs = <String>[
      '--sdk-root',
      'sdkroot',
      '--strong',
    ];

    test('compile one file', () async {
      final StreamController<List<int>> inputStreamController =
        new StreamController<List<int>>();
      final ReceivePort compileCalled = new ReceivePort();
      when(compiler.compile(any, any, generator: any)).thenAnswer(
        (Invocation invocation) {
          expect(invocation.positionalArguments[0], equals('server.dart'));
          expect(invocation.positionalArguments[1]['sdk-root'], equals('sdkroot'));
          expect(invocation.positionalArguments[1]['strong'], equals(false));
          compileCalled.sendPort.send(true);
        }
      );

      final int exitcode = await starter(args, compiler: compiler,
        input: inputStreamController.stream,
      );
      expect(exitcode, equals(0));
      inputStreamController.add('compile server.dart\n'.codeUnits);
      await compileCalled.first;
      inputStreamController.close();
    });

    test('compile one file (strong mode)', () async {
      final StreamController<List<int>> inputStreamController =
        new StreamController<List<int>>();
      final ReceivePort compileCalled = new ReceivePort();
      when(compiler.compile(any, any, generator: any)).thenAnswer(
        (Invocation invocation) {
          expect(invocation.positionalArguments[0], equals('server.dart'));
          expect(invocation.positionalArguments[1]['sdk-root'], equals('sdkroot'));
          expect(invocation.positionalArguments[1]['strong'], equals(true));
          compileCalled.sendPort.send(true);
        }
      );

      final int exitcode = await starter(strongArgs, compiler: compiler,
        input: inputStreamController.stream,
      );
      expect(exitcode, equals(0));
      inputStreamController.add('compile server.dart\n'.codeUnits);
      await compileCalled.first;
      inputStreamController.close();
    });

    test('compile few files', () async {
      final StreamController<List<int>> streamController =
        new StreamController<List<int>>();
      final ReceivePort compileCalled = new ReceivePort();
      int counter = 1;
      when(compiler.compile(any, any, generator: any)).thenAnswer(
        (Invocation invocation) {
          expect(invocation.positionalArguments[0], equals('server${counter++}.dart'));
          expect(invocation.positionalArguments[1]['sdk-root'], equals('sdkroot'));
          expect(invocation.positionalArguments[1]['strong'], equals(false));
          compileCalled.sendPort.send(true);
        }
      );

      final int exitcode = await starter(args, compiler: compiler,
        input: streamController.stream,
      );
      expect(exitcode, equals(0));
      streamController.add('compile server1.dart\n'.codeUnits);
      streamController.add('compile server2.dart\n'.codeUnits);
      await compileCalled.first;
      streamController.close();
    });
  });

  group('interactive incremental compile with mocked compiler', () {
    final CompilerInterface compiler = new _MockedCompiler();

    final List<String> args = <String>[
      '--sdk-root',
      'sdkroot',
      '--incremental'
    ];

    test('recompile few files', () async {
      final StreamController<List<int>> streamController =
        new StreamController<List<int>>();
      final ReceivePort recompileCalled = new ReceivePort();

      when(compiler.recompileDelta(filename: null)).thenAnswer((Invocation invocation) {
        recompileCalled.sendPort.send(true);
      });
      final int exitcode = await starter(args, compiler: compiler,
        input: streamController.stream,
      );
      expect(exitcode, equals(0));
      streamController.add('recompile abc\nfile1.dart\nfile2.dart\nabc\n'.codeUnits);
      await recompileCalled.first;

      verifyInOrder(
        <void>[
          compiler.invalidate(Uri.base.resolve('file1.dart')),
          compiler.invalidate(Uri.base.resolve('file2.dart')),
          await compiler.recompileDelta(filename: null),
        ]
      );
      streamController.close();
    });

    test('recompile few files with new entrypoint', () async {
      final StreamController<List<int>> streamController =
      new StreamController<List<int>>();
      final ReceivePort recompileCalled = new ReceivePort();

      when(compiler.recompileDelta(filename: 'file2.dart')).thenAnswer((Invocation invocation) {
        recompileCalled.sendPort.send(true);
      });
      final int exitcode = await starter(args, compiler: compiler,
        input: streamController.stream,
      );
      expect(exitcode, equals(0));
      streamController.add('recompile file2.dart abc\nfile1.dart\nfile2.dart\nabc\n'.codeUnits);
      await recompileCalled.first;

      verifyInOrder(
          <void>[
            compiler.invalidate(Uri.base.resolve('file1.dart')),
            compiler.invalidate(Uri.base.resolve('file2.dart')),
            await compiler.recompileDelta(filename: 'file2.dart'),
          ]
      );
      streamController.close();
    });

    test('accept', () async {
      final StreamController<List<int>> inputStreamController =
      new StreamController<List<int>>();
      final ReceivePort acceptCalled = new ReceivePort();
      when(compiler.acceptLastDelta()).thenAnswer((Invocation invocation) {
        acceptCalled.sendPort.send(true);
      });
      final int exitcode = await starter(args, compiler: compiler,
        input: inputStreamController.stream,
      );
      expect(exitcode, equals(0));
      inputStreamController.add('accept\n'.codeUnits);
      await acceptCalled.first;
      inputStreamController.close();
    });

    test('reset', () async {
      final StreamController<List<int>> inputStreamController =
        new StreamController<List<int>>();
      final ReceivePort resetCalled = new ReceivePort();
      when(compiler.resetIncrementalCompiler()).thenAnswer((Invocation invocation) {
        resetCalled.sendPort.send(true);
      });
      final int exitcode = await starter(args, compiler: compiler,
        input: inputStreamController.stream,
      );
      expect(exitcode, equals(0));
      inputStreamController.add('reset\n'.codeUnits);
      await resetCalled.first;
      inputStreamController.close();
    });

    test('compile then recompile', () async {
      final StreamController<List<int>> streamController =
        new StreamController<List<int>>();
      final ReceivePort recompileCalled = new ReceivePort();

      when(compiler.recompileDelta(filename: null)).thenAnswer((Invocation invocation) {
        recompileCalled.sendPort.send(true);
      });
      final int exitcode = await starter(args, compiler: compiler,
        input: streamController.stream,
      );
      expect(exitcode, equals(0));
      streamController.add('compile file1.dart\n'.codeUnits);
      streamController.add('accept\n'.codeUnits);
      streamController.add('recompile def\nfile2.dart\nfile3.dart\ndef\n'.codeUnits);
      await recompileCalled.first;

      verifyInOrder(<void>[
        await compiler.compile('file1.dart', any, generator: any),
        compiler.acceptLastDelta(),
        compiler.invalidate(Uri.base.resolve('file2.dart')),
        compiler.invalidate(Uri.base.resolve('file3.dart')),
        await compiler.recompileDelta(filename: null),
      ]);
      streamController.close();
    });
  });

  group('interactive incremental compile with mocked IKG', () {
    final List<String> args = <String>[
      '--sdk-root',
      'sdkroot',
      '--incremental',
    ];

    test('compile then accept', () async {
      final StreamController<List<int>> streamController =
        new StreamController<List<int>>();
      final StreamController<List<int>> stdoutStreamController =
        new StreamController<List<int>>();
      final IOSink ioSink = new IOSink(stdoutStreamController.sink);
      ReceivePort receivedResult = new ReceivePort();

      String boundaryKey;
      stdoutStreamController.stream
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String s) {
          const String RESULT_OUTPUT_SPACE = 'result ';
          if (boundaryKey == null) {
            if (s.startsWith(RESULT_OUTPUT_SPACE)) {
              boundaryKey = s.substring(RESULT_OUTPUT_SPACE.length);
            }
          } else {
            if (s.startsWith(boundaryKey)) {
              boundaryKey = null;
              receivedResult.sendPort.send(true);
            }
          }
        });

      final _MockedIncrementalCompiler generator =
        new _MockedIncrementalCompiler();
      when(generator.compile())
          .thenAnswer((_) => new Future<Program>.value(new Program()));
      final _MockedBinaryPrinterFactory printerFactory =
        new _MockedBinaryPrinterFactory();
      when(printerFactory.newBinaryPrinter(any))
        .thenReturn(new _MockedBinaryPrinter());
      final int exitcode = await starter(args, compiler: null,
        input: streamController.stream,
        output: ioSink,
        generator: generator,
        binaryPrinterFactory: printerFactory,
      );
      expect(exitcode, equals(0));

      streamController.add('compile file1.dart\n'.codeUnits);
      await receivedResult.first;
      streamController.add('accept\n'.codeUnits);
      receivedResult = new ReceivePort();
      streamController.add('recompile def\nfile1.dart\ndef\n'.codeUnits);
      await receivedResult.first;

      streamController.close();
    });

    group('compile with output path', ()
    {
      final CompilerInterface compiler = new _MockedCompiler();

      test('compile from command line', () async {
        final List<String> args = <String>[
          'server.dart',
          '--sdk-root',
          'sdkroot',
          '--output-dill',
          '/foo/bar/server.dart.dill',
          '--output-incremental-dill',
          '/foo/bar/server.incremental.dart.dill',
        ];
        final int exitcode = await starter(args, compiler: compiler);
        expect(exitcode, equals(0));
        final List<ArgResults> capturedArgs =
            verify(
                compiler.compile(
                  argThat(equals('server.dart')),
                  captureAny,
                  generator: any,
                )
            ).captured;
        expect(capturedArgs.single['sdk-root'], equals('sdkroot'));
        expect(capturedArgs.single['strong'], equals(false));
      });
    });


  });
  return 0;
}
