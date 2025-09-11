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

`define	STATID_TimeCrouched			1076
`define	STATID_HumanKills			69

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

    ROPC = ROPlayerController(Sender.Owner);
    if (ROPC != None)
    {
        ROPC.ClientMessage("StatsFixer: Fixing your stats.");

        for (i = 0; i < StatsToFix.Length; ++i)
        {
            switch (StatsToFix[i].StatType)
            {
                // `sflog("checking DefStat: " @ StatInfoToString(StatsToFix[i]));

                case EST_Int:
                    IntStat = ROPC.StatsWrite.GetIntStat(StatsToFix[i].StatID);
                    if (IntStat < 0)
                    {
                        ROPC.StatsWrite.SetIntStat(StatsToFix[i].StatID, 0);
                    }
                    break;
                case EST_Float:
                    FloatStat = ROPC.StatsWrite.GetFloatStat(StatsToFix[i].StatID);
                    if (FloatStat < 0.0)
                    {
                        ROPC.StatsWrite.SetFloatStat(StatsToFix[i].StatID, 0.0);
                    }
                    break;
                default:
                    `sferror("invalid StatInfo:" @ StatInfoToString(StatsToFix[i]));
                    break;
            }
        }
    }
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

`define STATID__ {\`}STATID_
`define DefStatID(Name) `STATID__`_Name
`define DefStat(Name, Type) StatID=`DefStatID(`Name), StatName=`Name, StatType=`Type

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
    StatsToFix( 9)=(`DefStat(TimeCrouched,                  EST_Int))
    StatsToFix(10)=(`DefStat(TimeProned,                    EST_Int))
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
