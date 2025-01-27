// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/analyzer_error_code.dart';

// It is hard to visually separate each code's _doc comment_ from its published
// _documentation comment_ when each is written as an end-of-line comment.
// ignore_for_file: slash_for_doc_comments

/// The diagnostic codes associated with `dart:ffi`.
class FfiCode extends AnalyzerErrorCode {
  /**
   * No parameters.
   */
  static const FfiCode ANNOTATION_ON_POINTER_FIELD = FfiCode(
      name: 'ANNOTATION_ON_POINTER_FIELD',
      message:
          "Fields in a struct class whose type is 'Pointer' should not have "
          "any annotations.",
      correction: "Try removing the annotation.");

  /**
   * Parameters:
   * 0: the name of the argument
   */
  static const FfiCode ARGUMENT_MUST_BE_A_CONSTANT = FfiCode(
      name: 'ARGUMENT_MUST_BE_A_CONSTANT',
      message: "Argument '{0}' must be a constant.",
      correction: "Try replacing the value with a literal or const.");

  /**
   * No parameters.
   */
  static const FfiCode CREATION_OF_STRUCT_OR_UNION = FfiCode(
    name: 'CREATION_OF_STRUCT_OR_UNION',
    message: "Subclasses of 'Struct' and 'Union' are backed by native memory, "
        "and can't be instantiated by a generative constructor.",
    correction: "Try allocating it via allocation, or load from a 'Pointer'.",
  );

  /**
   * Parameters:
   * 0: the name of the struct class
   */
  static const FfiCode EMPTY_STRUCT = FfiCode(
      name: 'EMPTY_STRUCT',
      message: "Struct '{0}' is empty. Empty structs are undefined behavior.",
      correction: "Try adding a field to '{0}' or use a different Struct.");

  /**
   * No parameters.
   */
  static const FfiCode EXTRA_ANNOTATION_ON_STRUCT_FIELD = FfiCode(
      name: 'EXTRA_ANNOTATION_ON_STRUCT_FIELD',
      message: "Fields in a struct class must have exactly one annotation "
          "indicating the native type.",
      correction: "Try removing the extra annotation.");

  /**
   * No parameters.
   */
  static const FfiCode EXTRA_SIZE_ANNOTATION_CARRAY = FfiCode(
      name: 'EXTRA_SIZE_ANNOTATION_CARRAY',
      message: "'Array's must have exactly one 'Array' annotation.",
      correction: "Try removing the extra annotation.");

  /**
   * No parameters.
   */
  static const FfiCode FFI_NATIVE_ONLY_STATIC = FfiCode(
      name: 'FFI_NATIVE_ONLY_STATIC',
      message: "FfiNative annotations can only be used on static functions.",
      correction: "Change the method to static.");

  /**
   * No parameters.
   */
  static const FfiCode FIELD_IN_STRUCT_WITH_INITIALIZER = FfiCode(
      name: 'FIELD_IN_STRUCT_WITH_INITIALIZER',
      message:
          "Fields in subclasses of 'Struct' and 'Union' can't have initializers.",
      correction:
          "Try removing the initializer and marking the field as external.");

  /**
   * No parameters.
   */
  static const FfiCode FIELD_INITIALIZER_IN_STRUCT = FfiCode(
      name: 'FIELD_INITIALIZER_IN_STRUCT',
      message:
          "Constructors in subclasses of 'Struct' and 'Union' can't have field "
          "initializers.",
      correction: "Try removing the field initializer and marking the field as"
          " external.");

  /**
   * No parameters.
   */
  static const FfiCode FIELD_MUST_BE_EXTERNAL_IN_STRUCT = FfiCode(
      name: 'FIELD_MUST_BE_EXTERNAL_IN_STRUCT',
      message:
          "Fields of 'Struct' and 'Union' subclasses must be marked external.",
      correction: "Try adding the 'external' modifier.");

  /**
   * Parameters:
   * 0: the name of the struct class
   */
  static const FfiCode GENERIC_STRUCT_SUBCLASS = FfiCode(
      name: 'GENERIC_STRUCT_SUBCLASS',
      message:
          "The class '{0}' can't extend 'Struct' or 'Union' because it is generic.",
      correction: "Try removing the type parameters from '{0}'.");

  /**
   * No parameters.
   */
  static const FfiCode INVALID_EXCEPTION_VALUE = FfiCode(
      name: 'INVALID_EXCEPTION_VALUE',
      message:
          "The method 'Pointer.fromFunction' must not have an exceptional return "
          "value (the second argument) when the return type of the function is "
          "either 'void', 'Handle' or 'Pointer'.",
      correction: "Try removing the exceptional return value.");

  /**
   * Parameters:
   * 0: the type of the field
   */
  static const FfiCode INVALID_FIELD_TYPE_IN_STRUCT = FfiCode(
      name: 'INVALID_FIELD_TYPE_IN_STRUCT',
      message:
          "Fields in struct classes can't have the type '{0}'. They can only "
          "be declared as 'int', 'double', 'Array', 'Pointer', or subtype of "
          "'Struct' or 'Union'.",
      correction:
          "Try using 'int', 'double', 'Array', 'Pointer', or subtype of "
          "'Struct' or 'Union'.");

  /**
   * No parameters.
   */
  static const FfiCode LEAF_CALL_MUST_NOT_RETURN_HANDLE = FfiCode(
      name: 'LEAF_CALL_MUST_NOT_RETURN_HANDLE',
      message: "FFI leaf call must not return a Handle.",
      correction: "Try changing the return type to primitive or struct.");

  /**
   * No parameters.
   */
  static const FfiCode LEAF_CALL_MUST_NOT_TAKE_HANDLE = FfiCode(
      name: 'LEAF_CALL_MUST_NOT_TAKE_HANDLE',
      message: "FFI leaf call must not take arguments of type Handle.",
      correction: "Try changing the argument type to primitive or struct.");

  /**
   * No parameters.
   */
  static const FfiCode MISMATCHED_ANNOTATION_ON_STRUCT_FIELD = FfiCode(
      name: 'MISMATCHED_ANNOTATION_ON_STRUCT_FIELD',
      message: "The annotation does not match the declared type of the field.",
      correction: "Try using a different annotation or changing the declared "
          "type to match.");

  /**
   * No parameters.
   */
  static const FfiCode MISSING_ANNOTATION_ON_STRUCT_FIELD = FfiCode(
      name: 'MISSING_ANNOTATION_ON_STRUCT_FIELD',
      message:
          "Fields in a struct class must either have the type 'Pointer' or an "
          "annotation indicating the native type.",
      correction: "Try adding an annotation.");

  /**
   * No parameters.
   */
  static const FfiCode MISSING_EXCEPTION_VALUE = FfiCode(
      name: 'MISSING_EXCEPTION_VALUE',
      message:
          "The method 'Pointer.fromFunction' must have an exceptional return "
          "value (the second argument) when the return type of the function is "
          "neither 'void', 'Handle' or 'Pointer'.",
      correction: "Try adding an exceptional return value.");

  /**
   * Parameters:
   * 0: the type of the field
   */
  static const FfiCode MISSING_FIELD_TYPE_IN_STRUCT = FfiCode(
      name: 'MISSING_FIELD_TYPE_IN_STRUCT',
      message:
          "Fields in struct classes must have an explicitly declared type of "
          "'int', 'double' or 'Pointer'.",
      correction: "Try using 'int', 'double' or 'Pointer'.");

  /**
   * No parameters.
   */
  static const FfiCode MISSING_SIZE_ANNOTATION_CARRAY = FfiCode(
      name: 'MISSING_SIZE_ANNOTATION_CARRAY',
      message: "'Array's must have exactly one 'Array' annotation.",
      correction: "Try adding a 'Array' annotation.");

  /**
   * Parameters:
   * 0: the type that should be a valid dart:ffi native type.
   * 1: the name of the function whose invocation depends on this relationship
   */
  static const FfiCode MUST_BE_A_NATIVE_FUNCTION_TYPE = FfiCode(
      name: 'MUST_BE_A_NATIVE_FUNCTION_TYPE',
      message:
          "The type '{0}' given to '{1}' must be a valid 'dart:ffi' native "
          "function type.",
      correction: "Try changing the type to only use members for 'dart:ffi'.");

  /**
   * Parameters:
   * 0: the type that should be a subtype
   * 1: the supertype that the subtype is compared to
   * 2: the name of the function whose invocation depends on this relationship
   */
  static const FfiCode MUST_BE_A_SUBTYPE = FfiCode(
      name: 'MUST_BE_A_SUBTYPE',
      message: "The type '{0}' must be a subtype of '{1}' for '{2}'.",
      correction: "Try changing one or both of the type arguments.");

  /**
   * Parameters:
   * 0: the name of the function, method, or constructor having type arguments
   */
  static const FfiCode NON_CONSTANT_TYPE_ARGUMENT = FfiCode(
      name: 'NON_CONSTANT_TYPE_ARGUMENT',
      message:
          "The type arguments to '{0}' must be compile time constants but type "
          "parameters are not constants.",
      correction: "Try changing the type argument to be a constant type.");

  /**
   * Parameters:
   * 0: the type that should be a valid dart:ffi native type.
   */
  static const FfiCode NON_NATIVE_FUNCTION_TYPE_ARGUMENT_TO_POINTER = FfiCode(
      name: 'NON_NATIVE_FUNCTION_TYPE_ARGUMENT_TO_POINTER',
      message: "The type argument for the pointer '{0}' must be a "
          "'NativeFunction' in order to use 'asFunction'.",
      correction: "Try changing the type argument to be a 'NativeFunction'.");

  /**
   * No parameters.
   */
  static const FfiCode NON_POSITIVE_ARRAY_DIMENSION = FfiCode(
      name: 'NON_POSITIVE_ARRAY_DIMENSION',
      message: "Array dimensions must be positive numbers.",
      correction: "Try changing the input to a positive number.");

  /**
   * Parameters:
   * 0: the type of the field
   */
  static const FfiCode NON_SIZED_TYPE_ARGUMENT = FfiCode(
      name: 'NON_SIZED_TYPE_ARGUMENT',
      message:
          "Type arguments to '{0}' can't have the type '{1}'. They can only "
          "be declared as native integer, 'Float', 'Double', 'Pointer', or "
          "subtype of 'Struct' or 'Union'.",
      correction: "Try using a native integer, 'Float', 'Double', 'Pointer', "
          "or subtype of 'Struct' or 'Union'.");

  /**
   * No parameters.
   */
  static const FfiCode PACKED_ANNOTATION = FfiCode(
      name: 'PACKED_ANNOTATION',
      message: "Structs must have at most one 'Packed' annotation.",
      correction: "Try removing extra 'Packed' annotations.");

  /**
   * No parameters.
   */
  static const FfiCode PACKED_ANNOTATION_ALIGNMENT = FfiCode(
      name: 'PACKED_ANNOTATION_ALIGNMENT',
      message: "Only packing to 1, 2, 4, 8, and 16 bytes is supported.",
      correction:
          "Try changing the 'Packed' annotation alignment to 1, 2, 4, 8, or 16.");

  /**
   * Parameters:
   * 0: the name of the outer struct
   * 1: the name of the struct being nested
   */
  static const FfiCode PACKED_NESTING_NON_PACKED = FfiCode(
      name: 'PACKED_NESTING_NON_PACKED',
      message:
          "Nesting the non-packed or less tightly packed struct '{0}' in a packed struct '{1}' is not supported.",
      correction:
          "Try packing the nested struct or packing the nested struct more tightly.");

  /**
   * No parameters.
   */
  static const FfiCode SIZE_ANNOTATION_DIMENSIONS = FfiCode(
      name: 'SIZE_ANNOTATION_DIMENSIONS',
      message:
          "'Array's must have an 'Array' annotation that matches the dimensions.",
      correction: "Try adjusting the arguments in the 'Array' annotation.");

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_FFI_CLASS_IN_EXTENDS = FfiCode(
    name: 'SUBTYPE_OF_FFI_CLASS',
    message: "The class '{0}' can't extend '{1}'.",
    correction: "Try extending 'Struct' or 'Union'.",
    uniqueName: 'SUBTYPE_OF_FFI_CLASS_IN_EXTENDS',
  );

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_FFI_CLASS_IN_IMPLEMENTS = FfiCode(
    name: 'SUBTYPE_OF_FFI_CLASS',
    message: "The class '{0}' can't implement '{1}'.",
    correction: "Try extending 'Struct' or 'Union'.",
    uniqueName: 'SUBTYPE_OF_FFI_CLASS_IN_IMPLEMENTS',
  );

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_FFI_CLASS_IN_WITH = FfiCode(
    name: 'SUBTYPE_OF_FFI_CLASS',
    message: "The class '{0}' can't mix in '{1}'.",
    correction: "Try extending 'Struct' or 'Union'.",
    uniqueName: 'SUBTYPE_OF_FFI_CLASS_IN_WITH',
  );

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_STRUCT_CLASS_IN_EXTENDS = FfiCode(
    name: 'SUBTYPE_OF_STRUCT_CLASS',
    message: "The class '{0}' can't extend '{1}' because '{1}' is a subtype of "
        "'Struct' or 'Union'.",
    correction: "Try extending 'Struct' or 'Union' directly.",
    uniqueName: 'SUBTYPE_OF_STRUCT_CLASS_IN_EXTENDS',
  );

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_STRUCT_CLASS_IN_IMPLEMENTS = FfiCode(
    name: 'SUBTYPE_OF_STRUCT_CLASS',
    message:
        "The class '{0}' can't implement '{1}' because '{1}' is a subtype of "
        "'Struct' or 'Union'.",
    correction: "Try extending 'Struct' or 'Union' directly.",
    uniqueName: 'SUBTYPE_OF_STRUCT_CLASS_IN_IMPLEMENTS',
  );

  /**
   * Parameters:
   * 0: the name of the subclass
   * 1: the name of the class being extended, implemented, or mixed in
   */
  static const FfiCode SUBTYPE_OF_STRUCT_CLASS_IN_WITH = FfiCode(
    name: 'SUBTYPE_OF_STRUCT_CLASS',
    message: "The class '{0}' can't mix in '{1}' because '{1}' is a subtype of "
        "'Struct' or 'Union'.",
    correction: "Try extending 'Struct' or 'Union' directly.",
    uniqueName: 'SUBTYPE_OF_STRUCT_CLASS_IN_WITH',
  );

  /// Initialize a newly created error code to have the given [name]. If
  /// [uniqueName] is provided, then it will be used to construct the unique
  /// name for the code, otherwise the name will be used to construct the unique
  /// name.
  ///
  /// The message associated with the error will be created from the given
  /// [message] template. The correction associated with the error will be
  /// created from the given [correction] template.
  ///
  /// If [hasPublishedDocs] is `true` then a URL for the docs will be generated.
  const FfiCode({
    String? correction,
    bool hasPublishedDocs = false,
    required String message,
    required String name,
    String? uniqueName,
  }) : super(
          correction: correction,
          hasPublishedDocs: hasPublishedDocs,
          message: message,
          name: name,
          uniqueName: 'FfiCode.${uniqueName ?? name}',
        );

  @override
  ErrorSeverity get errorSeverity => type.severity;

  @override
  ErrorType get type => ErrorType.COMPILE_TIME_ERROR;
}
