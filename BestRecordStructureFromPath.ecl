/***
 * Function macro that allows you to call BestRecordStructure knowing only its
 * path.  The path is examined to determine its underlying type, record
 * structure and (if necessary) other metadata information needed in order to
 * construct a DATASET declaration for it.  The dataset is then passed to the
 * BestRecordStructure() function macro for evaluation.
 *
 * For non-flat files, it is important that a record definition be available
 * in the file's metadata.  For just-sprayed files, this is commonly defined
 * in the first line of the file and furthermore that the "Record Structure
 * Present" option in the spray dialog box had been checked.
 *
 * Note that this function requires HPCC Systems version 6.4.0 or later.  It
 * leverages the dynamic record lookup capabilities added to that version and
 * described in https://hpccsystems.com/blog/file-layout-resolution-compile-time.
 *
 * @param   path            The full path to the file to profile; REQUIRED
 * @param   sampling        A positive integer representing a percentage of
 *                          the file to examine, which is useful when analyzing a
 *                          very large dataset and only an estimatation is
 *                          sufficient; valid range for this argument is
 *                          1-100; values outside of this range will be
 *                          clamped; OPTIONAL, defaults to 100 (which indicates
 *                          that the entire dataset will be analyzed)
 * @param   emitTransform   Boolean governing whether the function emits a
 *                          TRANSFORM function that could be used to rewrite
 *                          the dataset into the 'best' record definition;
 *                          OPTIONAL, defaults to FALSE.
 * @param   textOutput      Boolean governing the type of result that is
 *                          delivered by this function; if FALSE then a
 *                          recordset of STRINGs will be returned; if TRUE
 *                          then a dataset with a single STRING field, with
 *                          the contents formatted for HTML, will be
 *                          returned (this is the ideal output if the
 *                          intention is to copy the output from ECL Watch);
 *                          OPTIONAL, defaults to FALSE
 *
 * @return  A recordset defining the best ECL record structure for the data.
 *          If textOutput is FALSE (the default) then each record will contain
 *          one field declaration, and the list of declarations will be wrapped
 *          with RECORD and END strings; if the emitTransform argument was
 *          TRUE, there will also be a set of records that that comprise a
 *          stand-alone TRANSFORM function.  If textOutput is TRUE then only
 *          one record will be returned, containing an HTML-formatted string
 *          containing the new field declarations (and optionally the
 *          TRANSFORM); this is the ideal format if the intention is to copy
 *          the result from ECL Watch.
 */
EXPORT BestRecordStructureFromPath(path, sampling = 100, emitTransform = FALSE, textOutput = FALSE) := FUNCTIONMACRO
    IMPORT DataPatterns;
    IMPORT Std;

    // Attribute naming note:  In order to reduce symbol collisions with calling
    // code, all LOCAL attributes are prefixed with two underscore characters;
    // normally, a #UNIQUENAME would be used instead, but there is apparently
    // a problem with using that for ECL attributes when another function
    // macro is called (namely, BestRecordStructure); using double underscores
    // is not an optimal solution but the chance of symbol collision should at
    // least be reduced

    // Function for gathering metadata associated with a file path
    LOCAL __GetFileAttribute(STRING attr) := NOTHOR(Std.File.GetLogicalFileAttribute(path, attr));

    // Gather certain metadata about the given path
    LOCAL __fileKind := __GetFileAttribute('kind');
    LOCAL __headerLineCnt := (UNSIGNED2)__GetFileAttribute('headerLength');

    // Dataset declaration for a delimited file
    LOCAL __csvDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            CSV(HEADING(__headerLineCnt)) // other settings will default to metadata values
        );

    // Dataset declaration for a flat file
    LOCAL __flatDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            FLAT
        );

    // The returned value needs to be in a common format; the format here was
    // extracted from the DataPatterns.BestRecordStructure code
    LOCAL __CommonResultRec :=
        #IF((BOOLEAN)textOutput)
            {STRING result__html}
        #ELSE
            {STRING s}
        #END;

    LOCAL __RunBestRecordStructure(tempFile, _sampleSize, _emitTransform, _textOutput) := FUNCTIONMACRO
        LOCAL __theResult := DataPatterns.BestRecordStructure(tempFile, _sampleSize, _emitTransform, _textOutput);

        RETURN PROJECT
            (
                __theResult,
                TRANSFORM
                    (
                        __CommonResultRec,
                        SELF := LEFT
                    )
            );
    ENDMACRO;

    LOCAL __resultStructure := CASE
        (
            TRIM(__fileKind, ALL),
            'flat'  =>  __RunBestRecordStructure(__flatDataset, sampling, emitTransform, textOutput),
            'csv'   =>  __RunBestRecordStructure(__csvDataset, sampling, emitTransform, textOutput),
            ''      =>  __RunBestRecordStructure(__csvDataset, sampling, emitTransform, textOutput),
            ERROR(DATASET([], __CommonResultRec), 'Cannot run BestRecordStructure on file of kind "' + __fileKind + '"')
        );

    RETURN __resultStructure;
ENDMACRO;
