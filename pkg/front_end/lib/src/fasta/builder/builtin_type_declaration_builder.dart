// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.builtin_type_builder;

import 'package:kernel/ast.dart' show DartType, Nullability;

import 'library_builder.dart';
import 'nullability_builder.dart';
import 'type_builder.dart';

import 'type_declaration_builder.dart';

abstract class BuiltinTypeDeclarationBuilder
    extends TypeDeclarationBuilderImpl {
  final DartType type;

  @override
  final Uri fileUri;

  BuiltinTypeDeclarationBuilder(
      String name, this.type, LibraryBuilder compilationUnit, int charOffset)
      : fileUri = compilationUnit.fileUri,
        super(null, 0, name, compilationUnit, charOffset);

  @override
  DartType buildType(LibraryBuilder library,
      NullabilityBuilder nullabilityBuilder, List<TypeBuilder>? arguments,
      {bool? nonInstanceContext}) {
    return type.withDeclaredNullability(nullabilityBuilder.build(library));
  }

  @override
  DartType buildTypesWithBuiltArguments(LibraryBuilder library,
      Nullability nullability, List<DartType> arguments) {
    return type.withDeclaredNullability(nullability);
  }

  @override
  String get debugName => "BuiltinTypeDeclarationBuilder";
}
