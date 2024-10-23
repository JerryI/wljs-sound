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



Unprotect[Audio`AudioGUIDump`audioBoxes]
Unprotect[Audio]
ClearAll[Audio`AudioGUIDump`audioBoxes]


Begin["`Internal`"]

Audio /: Audio`AudioGUIDump`audioBoxes[a_Audio, audioID_ , appearance_, form_] := AudioWrapperBox[a, form]


Unprotect[Sound`soundDisplay]
ClearAll[Sound`soundDisplay]
Unprotect[System`Dump`soundDisplay]
ClearAll[System`Dump`soundDisplay]
System`Dump`soundDisplay[s_]:=$Failed 
Sound`soundDisplay[s_] := $Failed 

Unprotect[Sound]

Sound /: MakeBoxes[s_Sound, form: StandardForm] := With[{
  o = CreateFrontEndObject[s]
},
  If[ByteCount[s] < 1024,
    ViewBox[s, o]
  ,
    MakeBoxes[o, form]
  ]
  
]

System`WLXForm;

Unprotect[Sound]
Sound /: MakeBoxes[s_Sound, WLXForm] := With[{o = CreateFrontEndObject[s]},
  MakeBoxes[o, WLXForm]
]

Unprotect[Audio]
Audio /: MakeBoxes[s_Audio, WLXForm] := With[{},
  AudioWrapperBox[s, WLXForm]
]


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

PCMPlayer /: MakeBoxes[p_PCMPlayer, WLXForm] := With[{o = CreateFrontEndObject[p]},
    MakeBoxes[o, WLXForm]
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
            chunks, index, Global`buffer, partLength,
            skipNext = False
        },
            With[{parts = (ByteCount[data] / (1.0 1024 1024)) // Floor},
                If[parts < 2,
                    partLength = Length[data];
                ,
                    partLength = Min[Ceiling[Length[data] / parts], Length[data] ];
                ]
            ];

            AppendTo[garbage, Hold[Global`buffer] ];
            
            index = partLength;
            chunks = data;
            Global`buffer = Take[chunks, partLength];

            EventHandler[uid, {"More" -> Function[Null, 
                If[skipNext, skipNext = False; Return[] ];
                
                If[index + partLength - 1 > Length[chunks],
                    If[Length[chunks] - index <= 1, 
                        index = 1;
                        skipNext = True;
                    ,
                        Global`buffer = chunks[[index ;;  ]];
                    ]
                ,
                    Global`buffer = chunks[[index ;; index + partLength - 1 ]];
                    index = index + partLength;
                ];


                
                    
                ],
            
            "Stop" -> Function[Null,
                index = 1;
                skipNext = False;
            ]  
            }];

            With[{o = CreateFrontEndObject[PCMPlayer[Global`buffer // Offload, Global`buffer, "SignedInteger16", "AutoPlay"->False, "Event"->uid, "FullLength"->Length[chunks], SampleRate -> options[SampleRate] ] ]},
                MakeBoxes[o, form]
            ]  
        ]
    ,

        With[{o = CreateFrontEndObject[PCMPlayer[data, "SignedInteger16", "AutoPlay"->False, SampleRate -> options[SampleRate] ] ]},
                    MakeBoxes[o, form]
                ] 


    ]
]

audioDumpTemporal = {};

AudioWrapperBox[a_Audio, StandardForm] := With[{
    options = <|SampleRate -> QuantityMagnitude[ Information[a]["SampleRate"] ] |>,
    data = extractChannelTyped[a, "SignedInteger16"],
    uid = CreateUUID[]
},
    AppendTo[garbage, Hold[a] ]; (* prvent form garbage collecting *)

    If[ByteCount[data] > 1.0 1024 1024,
        LeakyModule[{
            chunks, index, Global`buffer, partLength,
            skipNext = False
        },
            With[{parts = (ByteCount[data] / (1.0 1024 1024)) // Floor},
                If[parts < 2,
                    partLength = Length[data];
                ,
                    partLength = Min[Ceiling[Length[data] / parts], Length[data] ];
                ]
            ];

            AppendTo[garbage, Hold[Global`buffer] ];
            
            index = partLength;
            chunks = data;
            Global`buffer = Take[chunks, partLength];

            EventHandler[uid, {"More" -> Function[Null, 
                If[skipNext, skipNext = False; Return[] ];
                
                If[index + partLength - 1 > Length[chunks],
                    If[Length[chunks] - index <= 1, 
                        index = 1;
                        skipNext = True;
                    ,
                        Global`buffer = chunks[[index ;;  ]];
                    ]
                ,
                    Global`buffer = chunks[[index ;; index + partLength - 1 ]];
                    index = index + partLength;
                ];


                
                    
                ],
            
            "Stop" -> Function[Null,
                index = 1;
                skipNext = False;
            ]  
            }];

            With[{interpretation = ToString[a, InputForm]},
                If[StringLength[interpretation] > 5000,
                    Module[{dump},

                        AppendTo[audioDumpTemporal, Hold[dump] ];
                        

                        With[{result = With[{o = CreateFrontEndObject[PCMPlayer[Global`buffer // Offload, Global`buffer, "SignedInteger16", "AutoPlay"->False, "Event"->uid, "FullLength"->Length[chunks], SampleRate -> options[SampleRate] ] ]},
                            RowBox[{"(*VB[*)(", ToString[dump, InputForm], ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
                        ] },

                            dump = a;
                            result
                        ]                  
                    ]
                ,
                    With[{o = CreateFrontEndObject[PCMPlayer[Global`buffer // Offload, Global`buffer, "SignedInteger16", "AutoPlay"->False, "Event"->uid, "FullLength"->Length[chunks], SampleRate -> options[SampleRate] ] ]},
                        RowBox[{"(*VB[*)(", interpretation, ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
                    ]                  
                ]
          
            ]
        ]
    ,

        With[{interpretation = ToString[a, InputForm]},
            If[StringLength[interpretation] > 5000 && True,
                Module[{dump},

                    AppendTo[audioDumpTemporal, Hold[dump] ];
                    

                    With[{result = With[{o = CreateFrontEndObject[PCMPlayer[data, "SignedInteger16", "AutoPlay"->False, SampleRate -> options[SampleRate] ] ]},
                        RowBox[{"(*VB[*)(", ToString[dump, InputForm], ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
                    ]  },

                        dump = a;
                        result

                    ]                
                ]
            ,
                With[{o = CreateFrontEndObject[PCMPlayer[data, "SignedInteger16", "AutoPlay"->False, SampleRate -> options[SampleRate] ] ]},
                    RowBox[{"(*VB[*)(", interpretation, ")(*,*)(*", ToString[Compress[Hold[o] ], InputForm], "*)(*]VB*)"}]
                ]                 
            ]
        
        ]


    ]
]





End[]
EndPackage[]
