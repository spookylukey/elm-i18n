module CSV.Import exposing (generate)

import Csv
import Dict
import Regex exposing (Regex)
import Set


{-| Generates elm code for localized elements for multiple modules, from a CSV
string. The CSV string is expected to have the following columns:
modulename, key, comment, placeholders, value

This matches the export format generated by CSV.Export.
-}
generate : String -> List ( String, String )
generate csv =
    case Csv.parse csv of
        Result.Ok lines ->
            let
                modules =
                    allModuleNames lines.records
                        |> Set.fromList
                        |> Set.toList

                -- The lines can contain multiple modules.
                -- Generate a dictionary of all modules and there respective lines in the CSV.
                linesForModules =
                    modules
                        |> List.map
                            (\name ->
                                ( name
                                , linesForModule name lines.records
                                )
                            )
                        |> Dict.fromList

                -- Generate the source code for each module based on the lines
                -- grouped in the expression above.
                souresForModules =
                    List.map
                        (\name ->
                            let
                                linesForThisModule =
                                    Dict.get name linesForModules
                                        |> Maybe.withDefault []
                            in
                                ( name, generateForModule name linesForThisModule )
                        )
                        modules
            in
                souresForModules

        Result.Err err ->
            Debug.log "Could not parse CSV" err
                |> always []


generateForModule : String -> List (List String) -> String
generateForModule moduleName lines =
    List.filterMap fromLine lines
        |> String.join "\n\n\n"
        |> String.append ("module " ++ moduleName ++ " exposing (..)\n\n\n")
        |> -- append new line at end of file
           (flip String.append) "\n"


allModuleNames : List (List String) -> List String
allModuleNames lines =
    List.filterMap moduleNameForLine lines


moduleNameForLine : List String -> Maybe String
moduleNameForLine columns =
    case columns of
        [ modulename, key, comment, placeholders, value ] ->
            Just modulename

        _ ->
            Nothing


linesForModule : String -> List (List String) -> List (List String)
linesForModule moduleName lines =
    List.filter (\line -> moduleNameForLine line == Just moduleName) lines


fromLine : List String -> Maybe String
fromLine columns =
    case columns of
        [ modulename, key, comment, placeholders, value ] ->
            Just (code key comment placeholders value)

        _ ->
            Nothing


regexPlaceholder : Regex
regexPlaceholder =
    Regex.regex "\\{\\{([^\\}]*)\\}\\}"


regexTrailingEmptyString : Regex
regexTrailingEmptyString =
    Regex.regex "[\\s\\n]*\\+\\+\\s*\"\""


code : String -> String -> String -> String -> String
code key comment placeholderString value =
    let
        commentCode =
            if String.isEmpty comment then
                ""
            else
                "{-| " ++ comment ++ " -}\n"

        tab =
            "    "

        valueWithPlaceholders =
            Regex.replace Regex.All
                regexPlaceholder
                (\match ->
                    let
                        placeholder =
                            List.head match.submatches
                                |> Maybe.withDefault Nothing
                                |> Maybe.withDefault "unknown"
                    in
                        "\"\n"
                            ++ (tab ++ tab)
                            ++ ("++ " ++ placeholder)
                            ++ (tab ++ tab ++ "++ \"")
                )
                value

        -- clean up trailing `++ ""`
        implementation =
            ("\"" ++ valueWithPlaceholders ++ "\"")
                |> Regex.replace Regex.All regexTrailingEmptyString (always "")

        placeholders =
            String.split " " placeholderString
                |> List.map String.trim
                |> List.filter (String.isEmpty >> not)

        numPlaceholders =
            List.length placeholders

        functionArgument =
            if numPlaceholders == 0 then
                ""
            else
                " " ++ String.join " " placeholders

        functionSignature =
            List.repeat numPlaceholders " -> String"
                |> String.join ""
    in
        commentCode
            ++ (key ++ " : String" ++ functionSignature ++ "\n")
            ++ (key ++ functionArgument ++ " =\n")
            ++ (tab ++ (implementation))
