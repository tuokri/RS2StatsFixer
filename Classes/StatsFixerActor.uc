/*
 * Copyright (c) 2025 Tuomo Kriikkula
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

class StatsFixerActor extends Actor
    placeable;

enum EStatType
{
    EST_Int,
    EST_Float,
};

struct StatInfo
{
    var int StatID;
    var EStatType StatType;
    var name StatName;
};

// List of STATID_* definitions from ROGameStats.uci to fix.
var array<StatInfo> StatsToFix;

var StatsFixerMessagingSpectator MessagingSpec;

event PostBeginPlay()
{
    super.PostBeginPlay();

    if (WorldInfo.NetMode == NM_DedicatedServer && Role == ROLE_Authority)
    {
        MessagingSpec = Spawn(class'StatsFixerMessagingSpectator', self);
        MessagingSpec.SFOwner = self;
    }
    else
    {
        `sfdebug("not initializing messaging, NetMode="
            @ WorldInfo.NetMode $ ", Role=" @ Role);
    }

    `sflog(self @ "initialized");
}

function HandleDebugCommand(PlayerReplicationInfo Sender, string Msg)
{
`if(`isdefined(SF_DEBUG))
    local ROPlayerController ROPC;
    local array<string> Args;
    local int IntArg1;
    local int IntVal;
    local float FloatVal;
    local bool bFlush;

    bFlush = False;

    ROPC = ROPlayerController(Sender.Owner);
    if (ROPC == None)
    {
        `sferror("invalid Sender:" @ Sender);
        return;
    }

    Args = SplitString(Msg, " ", True);
    `sfdebug("Msg:" @ Msg);
    if (Args.Length == 0)
    {
        return;
    }

    // SetStat 1076 -4234.045 float
    // SetStat 1066 -6969 int
    if (Args[0] == "SetStat")
    {
        IntArg1 = int(Args[1]);
        `sfdebug("setting stat" @ IntArg1 @ "to" @ Args[2]);
        if (Args[3] ~= "int")
        {
            ROPC.StatsWrite.SetIntStat(IntArg1, int(Args[2]));
            bFlush = True;
        }
        else if (Args[3] ~= "float")
        {
            ROPC.StatsWrite.SetFloatStat(IntArg1, float(Args[2]));
            bFlush = True;
        }
        else
        {
            `sferror("invalid type:" @ Args[3]);
            return;
        }

        if (bFlush)
        {
            ROPC.OnlineSub.StatsInterface.WriteOnlineStats(
                'Game', ROPC.PlayerReplicationInfo.UniqueID, ROPC.StatsWrite);
            ROPC.OnlineSub.StatsInterface.FlushOnlineStats('Game');
        }
    }
    // GetStat 1076 float
    // GetStat 1066 int
    else if (Args[0] == "GetStat")
    {
        IntArg1 = int(Args[1]);
        `sfdebug("getting stat" @ IntArg1);
        if (Args[2] ~= "int")
        {
            IntVal = ROPC.StatsWrite.GetIntStat(IntArg1);
            ROPC.ClientMessage("Stat" @ IntArg1 @ "=" @ IntVal);
        }
        else if (Args[2] ~= "float")
        {
            FloatVal = ROPC.StatsWrite.GetFloatStat(IntArg1);
            ROPC.ClientMessage("Stat" @ IntArg1 @ "=" @ FloatVal);
        }
        else
        {
            `sferror("invalid type:" @ Args[2]);
            return;
        }
    }
    else
    {
        `sfdebug("unknown debug command:" @ Args[0]);
    }
`else
    return;
`endif
}

function ReceiveMessage(PlayerReplicationInfo Sender, string Msg, name Type)
{
    `sfdebug(
        self
        @ "Sender=" @ Sender
        @ "Msg=" @ Msg
        @ "Type=" @ Type
        @ "Role=" @ Role
    );

    if (Role != ROLE_Authority)
    {
        return;
    }

    if (Msg == "FixMe")
    {
        FixStats(Sender);
    }

`if(`isdefined(SF_DEBUG))
    HandleDebugCommand(Sender, Msg);
`endif
}

function FixStats(PlayerReplicationInfo Sender)
{
    local int i;
    local int IntStat;
    local float FloatStat;
    local ROPlayerController ROPC;
    local int NumFixed;

    NumFixed = 0;

    ROPC = ROPlayerController(Sender.Owner);
    if (ROPC != None)
    {
        ROPC.ClientMessage("StatsFixer: Fixing your stats.");

        for (i = 0; i < StatsToFix.Length; ++i)
        {
            `sflog("checking stat:" @ StatInfoToString(StatsToFix[i]));

            switch (StatsToFix[i].StatType)
            {
                case EST_Int:
                    IntStat = ROPC.StatsWrite.GetIntStat(StatsToFix[i].StatID);
                    `sflog(" " $ StatsToFix[i].StatID @ "current value: " @ IntStat);
                    if (IntStat < 0)
                    {
                        `sflog(" " $ StatsToFix[i].StatID @ "resetting to 0");
                        ROPC.StatsWrite.SetIntStat(StatsToFix[i].StatID, 0);
                        ++NumFixed;
                    }
                    break;
                case EST_Float:
                    FloatStat = ROPC.StatsWrite.GetFloatStat(StatsToFix[i].StatID);
                    `sflog(" " $ StatsToFix[i].StatID @ "current value: " @ FloatStat);
                    if (FloatStat < 0.0)
                    {
                        `sflog(" " $ StatsToFix[i].StatID @ "resetting to 0");
                        ROPC.StatsWrite.SetFloatStat(StatsToFix[i].StatID, 0.0);
                        ++NumFixed;
                    }
                    break;
                default:
                    `sferror("invalid StatInfo:" @ StatInfoToString(StatsToFix[i]));
                    break;
            }
        }
    }

    if (NumFixed > 0)
    {
        ROPC.OnlineSub.StatsInterface.WriteOnlineStats(
            'Game', ROPC.PlayerReplicationInfo.UniqueID, ROPC.StatsWrite);
        ROPC.OnlineSub.StatsInterface.FlushOnlineStats('Game');
        ROPC.ClientMessage("StatsFixer: Fixed" @ NumFixed @ "stats.");
    }
    else
    {
        ROPC.ClientMessage("StatsFixer: No stats needed fixing.");
    }

    ROPC.ClientMessage("StatsFixer: Please return to the main menu.");
}

event Destroyed()
{
    if (MessagingSpec != None)
    {
        MessagingSpec.Destroy();
        MessagingSpec = None;
    }

    super.Destroyed();
}

static function string StatInfoToString(StatInfo SI)
{
    return "(StatID=" $ SI.StatID $ ", StatType=" $ SI.StatType $ ", StatName=" $ SI.StatName $ ")";
}

// Helpers required due to lack of nested macros in UnrealScript.
const STATID_HumanKills = `STATID_HumanKills;
const STATID_MGKills = `STATID_MGKills;
const STATID_MeleeKills = `STATID_MeleeKills;
const STATID_SniperKills = `STATID_SniperKills;
const STATID_TEWins = `STATID_TEWins;
const STATID_SUWins = `STATID_SUWins;
const STATID_SKWins = `STATID_SKWins;
const STATID_FFWins = `STATID_FFWins;
const STATID_BayonetKills = `STATID_BayonetKills;
const STATID_TimeCrouched = `STATID_TimeCrouched;
const STATID_TimeProned = `STATID_TimeProned;
const STATID_Mantles = `STATID_Mantles;
const STATID_GunshipKills = `STATID_GunshipKills;
const STATID_HeloInsertions = `STATID_HeloInsertions;
const STATID_SpawnsInHelos = `STATID_SpawnsInHelos;
const STATID_CobraTurretKills = `STATID_CobraTurretKills;
const STATID_TimeInCamo = `STATID_TimeInCamo;
const STATID_DoorGunnerKills = `STATID_DoorGunnerKills;
const STATID_SprintDist = `STATID_SprintDist;
const STATID_CrouchSprintDist = `STATID_CrouchSprintDist;
const STATID_TimeOnLadders = `STATID_TimeOnLadders;
const STATID_BushrangerPilotKills = `STATID_BushrangerPilotKills;
const STATID_BushrangerGunnerKills = `STATID_BushrangerGunnerKills;
const STATID_GarandReloads = `STATID_GarandReloads;

`define DefStat(Name, Type) StatID=STATID_`Name, StatName=`Name, StatType=`Type

DefaultProperties
{
    StatsToFix.Add((`DefStat(HumanKills,                    EST_Int)))
    StatsToFix.Add((`DefStat(MGKills,                       EST_Int)))
    StatsToFix.Add((`DefStat(MeleeKills,                    EST_Int)))
    StatsToFix.Add((`DefStat(SniperKills,                   EST_Int)))
    StatsToFix.Add((`DefStat(TEWins,                        EST_Int)))
    StatsToFix.Add((`DefStat(SUWins,                        EST_Int)))
    StatsToFix.Add((`DefStat(SKWins,                        EST_Int)))
    StatsToFix.Add((`DefStat(FFWins,                        EST_Int)))
    StatsToFix.Add((`DefStat(BayonetKills,                  EST_Int)))
    StatsToFix.Add((`DefStat(TimeCrouched,                  EST_Float)))
    StatsToFix.Add((`DefStat(TimeProned,                    EST_Float)))
    StatsToFix.Add((`DefStat(Mantles,                       EST_Int)))
    StatsToFix.Add((`DefStat(GunshipKills,                  EST_Int)))
    StatsToFix.Add((`DefStat(HeloInsertions,                EST_Int)))
    StatsToFix.Add((`DefStat(SpawnsInHelos,                 EST_Int)))
    StatsToFix.Add((`DefStat(CobraTurretKills,              EST_Int)))
    StatsToFix.Add((`DefStat(TimeInCamo,                    EST_Float)))
    StatsToFix.Add((`DefStat(DoorGunnerKills,               EST_Int)))
    StatsToFix.Add((`DefStat(SprintDist,                    EST_Int)))
    StatsToFix.Add((`DefStat(CrouchSprintDist,              EST_Int)))
    StatsToFix.Add((`DefStat(TimeOnLadders,                 EST_Float)))
    StatsToFix.Add((`DefStat(BushrangerPilotKills,          EST_Int)))
    StatsToFix.Add((`DefStat(BushrangerGunnerKills,         EST_Int)))
    StatsToFix.Add((`DefStat(GarandReloads,                 EST_Int)))

    Begin Object Class=SpriteComponent Name=Sprite
        Sprite=Texture2D'EditorResources.VolumePath'
        HiddenGame=True
        AlwaysLoadOnClient=False
        AlwaysLoadOnServer=False
    End Object
    Components.Add(Sprite)

    RemoteRole=ROLE_AutonomousProxy
    NetUpdateFrequency=100
    bHidden=True
    bOnlyDirtyReplication=True
    bAlwaysRelevant=True
    bSkipActorPropertyReplication=True
    bAlwaysTick=True
    bNoDelete=True
    bGameRelevant=True
    bMovable=False
}
