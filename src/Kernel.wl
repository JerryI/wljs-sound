BeginPackage["Notebook`Editor`Kernel`PCMAudio`", {
    "JerryI`Misc`Events`",
    "JerryI`Misc`Events`Promise`",
	"Notebook`Editor`Kernel`FrontSubmitService`",
    "Notebook`Editor`FrontendObject`",
    "Notebook`Editor`Kernel`FrontSubmitService`MetaMarkers`"    
}]

PCMPlayer::usage = "PCMPlayer[data_Offload, type_String, opts___] creates a streaming PCM player"

Begin["`Internal`"]

PCMPlayer[a_Audio] := With[{info = Information[a]},
    If[MemberQ[{"Real32", "Real64"}, info["DataType"] ],
        PCMPlayer[AudioData[a, "SignedInteger16"]//First, "SignedInteger16", SampleRate -> QuantityMagnitude[ info["SampleRate"] ] ]
    ,
        PCMPlayer[AudioData[a, info["DataType"] ]//First, info["DataType"], SampleRate -> QuantityMagnitude[ info["SampleRate"] ] ]
    ]
]

PCMPlayer /: MakeBoxes[p_PCMPlayer, StandardForm] := With[{o = CreateFrontEndObject[p]},
    MakeBoxes[o, StandardForm]
]

End[]
EndPackage[]
