BeginPackage["Notebook`Editor`Kernel`PCMAudio`", {
    "JerryI`Misc`Language`",
    "JerryI`Misc`Events`",
    "JerryI`Misc`Events`Promise`",
    "JerryI`Misc`WLJS`Transport`",
	"Notebook`Editor`Kernel`FrontSubmitService`",
    "Notebook`Editor`FrontendObject`",
    "Notebook`Editor`Kernel`FrontSubmitService`MetaMarkers`"    
}]

PCMPlayer::usage = "PCMPlayer[data_Offload, type_String, opts___] creates a streaming PCM player"

System`AudioWrapperBox;
System`AudioWrapper;
AudioWrapper /: MakeBoxes[AudioWrapper[a_Audio], form_] := AudioWrapperBox[a, form];

Begin["`Internal`"]


extractChannelTyped[a_Audio, type_] := If[AudioChannels[a] > 1,
    AudioData[AudioChannelMix[a, "Mono"], type] // First
,
    AudioData[a, type] // First
]

PCMPlayer[a_Audio] := With[{info = Information[a]},
    If[MemberQ[{"Real32", "Real64"}, info["DataType"] ],
        PCMPlayer[extractChannelTyped[a, "SignedInteger16"], "SignedInteger16", SampleRate -> QuantityMagnitude[ info["SampleRate"] ] ]
    ,
        PCMPlayer[extractChannelTyped[a, info["DataType"] ], info["DataType"], SampleRate -> QuantityMagnitude[ info["SampleRate"] ] ]
    ]
]

PCMPlayer /: MakeBoxes[p_PCMPlayer, StandardForm] := With[{o = CreateFrontEndObject[p]},
    MakeBoxes[o, StandardForm]
]

Options[PCMPlayer] = {
    "AutoPlay" -> True,
    "Event" -> Null,
    SampleRate -> 44100,
    "GUI" -> True,
    "TimeAhead" -> 200,
    "FullLength" -> False
}

garbage = {};

AudioWrapperBox[a_Audio, form_] := With[{
    options = <|SampleRate -> QuantityMagnitude[ Information[a]["SampleRate"] ] |>,
    data = extractChannelTyped[a, "SignedInteger16"],
    uid = CreateUUID[]
},
    AppendTo[garbage, Hold[a] ]; (* prvent form garbage collecting *)
    
    If[ByteCount[data] > 1.0 1024 1024,
        LeakyModule[{
            chunks, index, Global`buffer, partLength = Ceiling[Length[data] / (ByteCount[data] / (1.0 1024 1024))],
            skipNext = False
        },
            AppendTo[garbage, Hold[Global`buffer] ];
            index = partLength;
            chunks = data;
            Global`buffer = Take[chunks, partLength];

            EventHandler[uid, {"More" -> Function[Null, 
                If[skipNext, skipNext = False; Return[] ];
                
                Global`buffer = chunks[[index ;; index + partLength - 1 ]];
                index = index + partLength;
                If[index + partLength - 1 > Length[chunks],
                    partLength = Length[chunks] - index;
                    If[partLength <= 1, 
                        index = 1;
                        partLength = Ceiling[Length[data] / (ByteCount[data] / 0.5 1024 1024)]; 
                        skipNext = True;
                    ]
                ];
            ],

            "Stop" -> Function[Null,
                index = Ceiling[Length[chunk] / (ByteCount[chunk] / (1.0 1024 1024))];
                skipNext = False;
            ] 
            
            }];

            With[{o = CreateFrontEndObject[PCMPlayer[Global`buffer // Offload, Global`buffer, "SignedInteger16", "AutoPlay"->False, "FullLength"->Length[chunks], "Event"->uid, SampleRate -> options[SampleRate] ] ]},
                MakeBoxes[o, form]
            ]            
        ]
    ,
        With[{o = CreateFrontEndObject[PCMPlayer[data, "SignedInteger16", "AutoPlay"->False, SampleRate -> options[SampleRate] ] ]},
            MakeBoxes[o, form]
        ]
    ]
]

AudioWrapperBox[a_Audio, StandardForm] := With[{
    options = <|SampleRate -> QuantityMagnitude[ Information[a]["SampleRate"] ] |>,
    data = extractChannelTyped[a, "SignedInteger16"],
    uid = CreateUUID[]
},
    AppendTo[garbage, Hold[a] ]; (* prvent form garbage collecting *)

    If[ByteCount[data] > 1.0 1024 1024,
        LeakyModule[{
            chunks, index, Global`buffer, partLength = Ceiling[Length[data] / (ByteCount[data] / (1.0 1024 1024))],
            skipNext = False
        },
            AppendTo[garbage, Hold[Global`buffer] ];
            
            index = partLength;
            chunks = data;
            Global`buffer = Take[chunks, partLength];

            EventHandler[uid, {"More" -> Function[Null, 
                If[skipNext, skipNext = False; Return[] ];
                
                Global`buffer = chunks[[index ;; index + partLength - 1 ]];
                index = index + partLength;
                If[index + partLength - 1 > Length[chunks],
                    partLength = Length[chunks] - index;
                    If[partLength <= 1, 
                        index = 1;
                        partLength = Ceiling[Length[data] / (ByteCount[data] / 0.5 1024 1024)]; 
                        skipNext = True;
                    ]
                ];
            ],
            
            "Stop" -> Function[Null,
                index = 1;
                skipNext = False;
            ]  
            }];

            With[{o = CreateFrontEndObject[PCMPlayer[Global`buffer // Offload, Global`buffer, "SignedInteger16", "AutoPlay"->False, "Event"->uid, "FullLength"->Length[chunks], SampleRate -> options[SampleRate] ] ]},
                RowBox[{"(*VB[*)(", ToString[a, InputForm], ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
            ]            
        ]
    ,
        With[{o = CreateFrontEndObject[PCMPlayer[data, "SignedInteger16", "AutoPlay"->False, SampleRate -> options[SampleRate] ] ]},
            RowBox[{"(*VB[*)(", ToString[a, InputForm], ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
        ]
    ]
]





End[]
EndPackage[]
