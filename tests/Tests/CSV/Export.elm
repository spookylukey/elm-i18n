module Tests.CSV.Export exposing (..)

import Expect
import Localized
import CSV.Export as CSV
import Test exposing (..)
import CSV.Template


all : Test
all =
    describe "Tests.CSV.Export"
        [ testExport ]


testExport : Test
testExport =
    test "testExport" <|
        \() ->
            CSV.generate elements
                |> Expect.equal expectedCSV


elements : List Localized.Element
elements =
    [ Localized.ElementStatic
        { key = "myString"
        , comment = "MyComment"
        , value = "Value"
        }
    , Localized.ElementFormat
        { key = "myFormat"
        , comment = ""
        , placeholders = [ "label" ]
        , components =
            [ Localized.FormatComponentStatic "Prefix: "
            , Localized.FormatComponentPlaceholder "label"
            ]
        }
    ]


expectedCSV : String
expectedCSV =
    CSV.Template.headers ++ """
"myString","MyComment","","Value"
"myFormat","","label","Prefix: {{label}}"
"""
