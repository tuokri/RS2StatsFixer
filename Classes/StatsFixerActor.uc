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

    MessagingSpec = Spawn(class'StatsFixerMessagingSpectator', self);
    MessagingSpec.SFOwner = self;

    `sflog(self @ "initialized");
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
    StatsToFix( 0)=(`DefStat(HumanKills,                    EST_Int))
    StatsToFix( 1)=(`DefStat(MGKills,                       EST_Int))
    StatsToFix( 2)=(`DefStat(MeleeKills,                    EST_Int))
    StatsToFix( 3)=(`DefStat(SniperKills,                   EST_Int))
    StatsToFix( 4)=(`DefStat(TEWins,                        EST_Int))
    StatsToFix( 5)=(`DefStat(SUWins,                        EST_Int))
    StatsToFix( 6)=(`DefStat(SKWins,                        EST_Int))
    StatsToFix( 7)=(`DefStat(FFWins,                        EST_Int))
    StatsToFix( 8)=(`DefStat(BayonetKills,                  EST_Int))
    StatsToFix( 9)=(`DefStat(TimeCrouched,                  EST_Float))
    StatsToFix(10)=(`DefStat(TimeProned,                    EST_Float))
    StatsToFix(11)=(`DefStat(Mantles,                       EST_Int))
    StatsToFix(12)=(`DefStat(GunshipKills,                  EST_Int))
    StatsToFix(13)=(`DefStat(HeloInsertions,                EST_Int))
    StatsToFix(14)=(`DefStat(SpawnsInHelos,                 EST_Int))
    StatsToFix(15)=(`DefStat(CobraTurretKills,              EST_Int))
    StatsToFix(16)=(`DefStat(TimeInCamo,                    EST_Float))
    StatsToFix(17)=(`DefStat(DoorGunnerKills,               EST_Int))
    StatsToFix(18)=(`DefStat(SprintDist,                    EST_Int))
    StatsToFix(19)=(`DefStat(CrouchSprintDist,              EST_Int))
    StatsToFix(20)=(`DefStat(TimeOnLadders,                 EST_Float))
    StatsToFix(21)=(`DefStat(BushrangerPilotKills,          EST_Int))
    StatsToFix(22)=(`DefStat(BushrangerGunnerKills,         EST_Int))
    StatsToFix(23)=(`DefStat(GarandReloads,                 EST_Int))

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
