// This file contains your Data Connector logic
section IterproAPIConnector;

host = "https://api.iterpro.com/";

IterproAPIConnector.GetCurrentCredential = () => Extension.CurrentCredential();

//apikey = ""; //Extension.CurrentCredential()[Key];

[DataSource.Kind="IterproAPIConnector", Publish="IterproAPIConnector.Publish"]

shared IterproAPIConnector.NavTableNested = (apikey as text) as table =>
    let

///////////////////////////////////////////////////////////////////////////
IterproAPIConnector.AuthController_paths = () => 
    let
        endpoint = "api/v1/auth/paths",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        json,


IterproAPIConnector.GetClubByID = () => 
    let
        endpoint = "api/v1/club",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),


IterproAPIConnector.ListAllTeams = () => 
    let
        endpoint = "api/v1/teams",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.GetTeamsListIdFiltred = (optional teams_id_list as text) =>
    let
         toList = Text.Split(teams_id_list, ";"),
         AllTeams = IterproAPIConnector.ListAllTeamsId(),
         filtredTeams = if teams_id_list is null then AllTeams else List.Select(AllTeams, (_) => List.Contains(toList, Text.BeforeDelimiter(_, " : ")))
    in
        List.Transform(filtredTeams, each Text.AfterDelimiter(_, " : ")),
        

IterproAPIConnector.ListAllTeamsId = () =>
    let
        Source = IterproAPIConnector.ListAllTeams(),
        RemovedOtherColumns = Table.SelectColumns(Source,{"_id", "name"}),
        TeaamIdNameTable = Table.AddColumn(RemovedOtherColumns, "teaamIdName", each [name] &" : " & [_id])
    in
        TeaamIdNameTable[teaamIdName],


IterproAPIConnector.ListAllPlayersByTeamId = () =>
let
    players = IterproAPIConnector.ListAllPlayers(),
    #"Removed Other Columns" = Table.SelectColumns(players,{"_id", "displayName", "position", "teamId"}),
    #"Merged Queries" = Table.NestedJoin(#"Removed Other Columns", {"teamId"}, IterproAPIConnector.ListAllTeams(), {"_id"}, "List all teams", JoinKind.LeftOuter),
    #"Expanded List all teams" = Table.ExpandTableColumn(#"Merged Queries", "List all teams", {"name"}, {"teams.name"}),
    #"Added Custom" = Table.AddColumn(#"Expanded List all teams", "player_team_id", each [displayName] &" : "& [teams.name] & " | " &[_id] & " : " &[teamId])
in
    #"Added Custom"[player_team_id],


IterproAPIConnector.ListAllSeasonsByTeamId = () =>
let
    Seasons = IterproAPIConnector.ListTeamSeasons(),
    #"Removed Other Columns" = Table.SelectColumns(Seasons,{"_id", "name", "teamId"}),
    #"Merged Queries" = Table.NestedJoin(#"Removed Other Columns", {"teamId"}, IterproAPIConnector.ListAllTeams(), {"_id"}, "List all teams", JoinKind.LeftOuter),
    #"Expanded List all teams" = Table.ExpandTableColumn(#"Merged Queries", "List all teams", {"name"}, {"teams.name"}),
    #"Added Custom" = Table.AddColumn(#"Expanded List all teams", "team_id_seasons", each [teams.name] &" : "& [name] & " | " &[teamId] & " : " &[_id])
in
    #"Added Custom"[team_id_seasons],



IterproAPIConnector.GetTeamByID = Value.ReplaceType(IterproAPIConnector.GetTeamByIDImpl, IterproAPIConnector.GetTeamByIDType),
IterproAPIConnector.GetTeamByIDImpl = (teamId as text) => 
    let
        endpoint = "api/v1/teams/" & Text.AfterDelimiter(teamId," : "),
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),


IterproAPIConnector.ListTeamInjuries = () => 
    let
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/injuries", []),
        teams = IterproAPIConnector.ListAllTeams()[_id],
        json = List.Combine(List.Transform( teams, each f(_) ))
    in
        toTable(json),

IterproAPIConnector.ListTeamEvents = Value.ReplaceType(IterproAPIConnector.ListTeamEventsImpl, IterproAPIConnector.ListTeamEventsType),
IterproAPIConnector.ListTeamEventsImpl = (
    optional teamName as text,
    optional from as text,
    optional to as text,
    optional seasonId as text
) => 
    let
        p = 
            let
                p0 = add_rec([], "from", from),
                p1 = add_rec(p0, "to", to),
                p2 = add_rec(p1, "seasonId", Text.AfterDelimiter( Text.AfterDelimiter( seasonId, " | "), " : "))
            in 
                p2,
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/events", p),
        teams = IterproAPIConnector.GetTeamsListIdFiltred(teamName),
        json = List.Combine( List.Transform( teams, each f(_) ) )
    in
        toTable(json),


IterproAPIConnector.ListScoutingPlayersForTeam = (optional teamName as text) =>
    let
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/scouting-players", []),
        teams = IterproAPIConnector.GetTeamsListIdFiltred(teamName),
        json = List.Combine(List.Transform( teams, each f(_) ))
    in
        toTable(json),

IterproAPIConnector.ListTeamSeasons = Value.ReplaceType(IterproAPIConnector.ListTeamSeasonsImpl, teamId_type),
IterproAPIConnector.ListTeamSeasonsImpl = (optional teamName as text) =>
    let
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/seasons", []),
        teams = IterproAPIConnector.GetTeamsListIdFiltred(teamName),
        json = List.Combine(List.Transform( teams, each f(_) ))
    in
        toTable(json),


IterproAPIConnector.ListAllTeamPlayers = Value.ReplaceType(IterproAPIConnector.ListAllTeamPlayersImpl, teamId_type),
IterproAPIConnector.ListAllTeamPlayersImpl = (optional teamName as text) =>
    let
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/players", []), //otherwise {[]},
        teams = IterproAPIConnector.GetTeamsListIdFiltred(teamName),
        json = List.Combine(List.Transform( teams, each f(_) ))
    in
        toTable(json),

IterproAPIConnector.ListAllPlayersId = () =>
    let
        Source = IterproAPIConnector.ListAllPlayers(),
        RemovedOtherColumns = Table.SelectColumns(Source,{"_id", "displayName"}),
        playerIdNameTable = Table.AddColumn(RemovedOtherColumns, "playerIdName", each [displayName] &" : " & [_id])
    in
        playerIdNameTable[playerIdName],


/*
IterproAPIConnector.ShowAScoutingPlayerForTeamGivenHisId = (team_id as text, playerId as text) =>
    let
        f = (t as text) => IterproAPIConnector.GetData( "api/v1/teams/" & t & "/players", []),
        teams = IterproAPIConnector.GetTeamsListIdFiltred(teamName),
        json = List.Combine(List.Transform( teams, each f(_) ))
    in
        toTable({json});*/


IterproAPIConnector.GetTeamPlayerByID = Value.ReplaceType(IterproAPIConnector.GetTeamPlayerByIDImpl, teamId_and_playerId),
IterproAPIConnector.GetTeamPlayerByIDImpl = (#"teamId : playerId" as text) => 
    let

        teamId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/teams/" & teamId & "players/" & playerId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),


IterproAPIConnector.ListAllPlayers = () =>
    let
        endpoint = "api/v1/players",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),



IterproAPIConnector.ListScoutingGames = () =>
    let
        endpoint = "api/v1/scouting-games",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListScoutingPlayers = () =>
    let
        endpoint = "api/v1/scouting-players",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListScoutingGamesForTeam = Value.ReplaceType(IterproAPIConnector.ListScoutingGamesForTeamImpl, teamId_type_1),
IterproAPIConnector.ListScoutingGamesForTeamImpl = (teamId as text) =>
    let
        endpoint = "api/v1/teams/" & Text.AfterDelimiter(teamId," : ") &"/scouting-games",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.ListScoutingLineupsForTeam = Value.ReplaceType(IterproAPIConnector.ListScoutingLineupsForTeamImpl, teamId_type_1),
IterproAPIConnector.ListScoutingLineupsForTeamImpl = (teamId as text) =>
    let
        endpoint = "api/v1/teams/" & Text.AfterDelimiter(teamId," : ") &"/scouting-lineups",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ShowAScoutingPlayerForTeamGivenHisId = Value.ReplaceType(IterproAPIConnector.ShowAScoutingPlayerForTeamGivenHisIdImpl, teamId_and_playerId),
IterproAPIConnector.ShowAScoutingPlayerForTeamGivenHisIdImpl = (#"teamId : playerId") =>
    let 
        teamId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/teams/teams/" & teamId &"/scouting-players/" & playerId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListTeamPlayerThresholds = Value.ReplaceType(IterproAPIConnector.ListTeamPlayerThresholdsImpl, teamId_and_playerId),
IterproAPIConnector.ListTeamPlayerThresholdsImpl = (#"teamId : playerId") =>
    let
        teamId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/teams/" & teamId& "/players/" & playerId &"/thresholds",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListTeamPlayerInjuries = Value.ReplaceType(IterproAPIConnector.ListTeamPlayerInjuriesImpl, teamId_and_playerId),
IterproAPIConnector.ListTeamPlayerInjuriesImpl = (#"teamId : playerId" as text) =>
    let
        teamId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/teams/" & teamId &"/players/" & playerId &"/injuries",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.GetTeamPlayerInjury = Value.ReplaceType(IterproAPIConnector.GetTeamPlayerInjuryImpl, injury_teamId_and_playerId),
IterproAPIConnector.GetTeamPlayerInjuryImpl = (injuryId as text, teamId as text, playerId as text) =>
    let 
        endpoint = "api/v1/teams/" & Text.AfterDelimiter(teamId," : ") &"/players/" & Text.AfterDelimiter(playerId," : ") &"/injuries/"&injuryId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),


IterproAPIConnector.ListTeamPlayerInjuryTreatments = Value.ReplaceType(IterproAPIConnector.ListTeamPlayerInjuryTreatmentsImpl, injury_teamId_and_playerId),
IterproAPIConnector.ListTeamPlayerInjuryTreatmentsImpl = (injuryId as text, teamId as text, playerId as text) =>
    let 
        endpoint = "api/v1/teams/" & Text.AfterDelimiter(teamId," : ") &"/players/" & Text.AfterDelimiter(playerId," : ") &"/injuries/" &injuryId &"/treatments",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListTeamPlayerRobustnessData = Value.ReplaceType(IterproAPIConnector.ListTeamPlayerRobustnessDataImpl, teamId_and_playerId),
IterproAPIConnector.ListTeamPlayerRobustnessDataImpl = (#"teamId : playerId" as text) =>
    let
        teamId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/teams/" & teamId &"/players/" & playerId &"/robustness",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.GetLineupForSeason = Value.ReplaceType(IterproAPIConnector.GetLineupForSeasonImpl, teamid_and_seasonid),
IterproAPIConnector.GetLineupForSeasonImpl = (#"teamId : seasonId" as text) =>
    let 

        seasonId = Text.AfterDelimiter( Text.AfterDelimiter( #"teamId : seasonId", " | "), " : "),
        teamId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : seasonId", " | "), " : "),

        endpoint = "api/v1/teams/" & teamId &"/seasons/" &seasonId &"/lineup",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ShowAScoutingGameGivenHisId = (gameId as text) =>
    let
        endpoint = "api/v1/scouting-games/"& gameId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),

IterproAPIConnector.ShowAScoutingGameForTeamGivenHisId = (teamId as text, gameId as text) =>
    let
        endpoint = "api/v1/teams/"&teamId&"/scouting-games/"&gameId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),

IterproAPIConnector.ListScoutingGameReportsGivenGameId = (gameId as text) =>
    let
        endpoint = "api/v1/scouting-games/"& gameId&"/reports",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.ListScoutingGameReportsForTeamGivenGameId = (teamId as text, gameId as text) =>
    let
        endpoint = "api/v1/teams/"&teamId&"/scouting-games/"&gameId&"/reports",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),
 
IterproAPIConnector.ShowAScoutingPlayerGivenHisId = Value.ReplaceType(IterproAPIConnector.ShowAScoutingPlayerGivenHisIdImpl, teamId_and_playerId),
IterproAPIConnector.ShowAScoutingPlayerGivenHisIdImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/scouting-players/" &playerId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListPlayerAttributesEntryData = Value.ReplaceType(IterproAPIConnector.ListPlayerAttributesEntryDataImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerAttributesEntryDataImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/scouting-players/" &playerId&"/attributes",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.ListPlayerDescriptionEntryData = Value.ReplaceType(IterproAPIConnector.ListPlayerDescriptionEntryDataImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerDescriptionEntryDataImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/scouting-players/" &playerId&"/description",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

/*
"GetPlayerByID",                 
"ListPlayerThresholds",          
"ListPlayerInjuries",            
"GetPlayerInjury",               
"ListPlayerTreatments",          
"ListPlayerRobustnessData",      
"ListPlayerInjuryTreatments",    
"ListPlayerAttributesEntryData", 
"ListPlayerDescriptionEntryData",
*/

IterproAPIConnector.GetPlayerByID = Value.ReplaceType(IterproAPIConnector.GetPlayerByIDImpl, teamId_and_playerId),
IterproAPIConnector.GetPlayerByIDImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),


IterproAPIConnector.ListPlayerThresholds = Value.ReplaceType(IterproAPIConnector.ListPlayerThresholdsImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerThresholdsImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/thresholds",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.ListPlayerInjuries = Value.ReplaceType(IterproAPIConnector.ListPlayerInjuriesImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerInjuriesImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/injuries",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.GetPlayerInjury = Value.ReplaceType(IterproAPIConnector.GetPlayerInjuryImpl, teamId_and_playerId_injury),
IterproAPIConnector.GetPlayerInjuryImpl = (#"teamId : playerId" as text, injuryId as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/injuries/"&injuryId,
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable({json}),

IterproAPIConnector.ListPlayerTreatments = Value.ReplaceType(IterproAPIConnector.ListPlayerTreatmentsImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerTreatmentsImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/treatments",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.ListPlayerRobustnessData = Value.ReplaceType(IterproAPIConnector.ListPlayerRobustnessDataImpl, teamId_and_playerId),
IterproAPIConnector.ListPlayerRobustnessDataImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/robustness",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),


IterproAPIConnector.ListPlayerInjuryTreatments = Value.ReplaceType(IterproAPIConnector.ListPlayerInjuryTreatmentsImpl, teamId_and_playerId_injury),
IterproAPIConnector.ListPlayerInjuryTreatmentsImpl = (#"teamId : playerId" as text, injuryId as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/injuries/"&injuryId&"/treatments",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.PlListPlayerAttributesEntryData = Value.ReplaceType(IterproAPIConnector.PlListPlayerAttributesEntryDataImpl, teamId_and_playerId),
IterproAPIConnector.PlListPlayerAttributesEntryDataImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/attributes",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),

IterproAPIConnector.PLListPlayerDescriptionEntryData = Value.ReplaceType(IterproAPIConnector.ListPlayerDescriptionEntryDataImpl, teamId_and_playerId),
IterproAPIConnector.PLListPlayerDescriptionEntryDataImpl = (#"teamId : playerId" as text) =>
    let 
        playerId = Text.BeforeDelimiter( Text.AfterDelimiter( #"teamId : playerId", " | "), " : "),
        endpoint = "api/v1/players/" &playerId&"/description",
        json = IterproAPIConnector.GetData(endpoint, [])
    in
        toTable(json),
///////////////////////////////////////////////////////////////////////////

IterproAPIConnector.GetData = (endpoint as text, params as record) =>
    let
        url = Uri.Combine(host, endpoint),
        h = [#"x-iterpro-api-key" = apikey],
        json = Json.Document( Web.Contents(url, [Headers = h, Query = params]) ) 
    in
        json,

///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////

IterproAPIConnector.GetTeamByIDType =
            type function (  
                             teamId as (type text meta [
                                Documentation.FieldCaption = "teamId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ])
                           )
                as function meta [
                    Documentation.Name = "GetTeamById",
                    Documentation.LongDescription = "GetTeamById"
            ],


teamId_type = 
             type function (  
                             optional teamName as (type text meta [
                                Documentation.FieldCaption = "teamName",
                                Documentation.FieldDescription = "Optional. Specify a list of TeamName separated by ;",
                                //Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId(),
                                Documentation.SampleValues = {"Team1;Team2;Team3...TeamN"}
                                ])
                           )
                as function,

teamId_type_1 =
            type function (  
                             teamId as (type text meta [
                                Documentation.FieldCaption = "teamId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ])
                           )
                as function
            ,


IterproAPIConnector.ListTeamEventsType =
            type function (  
                             optional teamName as (type text meta [
                                Documentation.FieldCaption = "teamName",
                                Documentation.FieldDescription = "Optional. Specify a list of TeamName separated by ;",
                                //Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId(),
                                Documentation.SampleValues = {"Team1;Team2;Team3...TeamN"}
                                ]),
                             optional from as (type text meta [
                                Documentation.FieldCaption = "from"
                                ]),
                             optional to as (type text meta [
                                Documentation.FieldCaption = "to"
                                ]),
                             optional seasonId as (type text meta [
                                Documentation.FieldCaption = "seasonId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllSeasonsByTeamId()
                                ])
                           )
                as function meta [
                    Documentation.Name = "ListTeamEventsType",
                    Documentation.LongDescription = "ListTeamEventsType"
            ],


playerid_and_teamid =  
        type function (      playerId  as (type text meta [
                                Documentation.FieldCaption = "playerId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllPlayersByTeamId()
                                ]),


                             teamId as (type text meta [
                                Documentation.FieldCaption = "teamId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ])
                           )
                as function
                ,


teamId_and_playerId =  
        type function (      #"teamId : playerId" as (type text meta [
                                Documentation.FieldCaption = "teamId : playerId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllPlayersByTeamId()
                                ])
                           )
                as function
                ,



injury_teamId_and_playerId = 
        type function (      
                             injuryId as (type text meta [
                                Documentation.FieldCaption = "injuryId"
                                //Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ]),
        
                             teamId as (type text meta [
                                Documentation.FieldCaption = "teamId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ]),
                              playerId  as (type text meta [
                                Documentation.FieldCaption = "playerId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllPlayersByTeamId()
                                ])
                           )
                as function
                ,

teamid_and_seasonid =  
        type function (      #"teamId : seasonId" as (type text meta [
                                Documentation.FieldCaption = "teamId : seasonId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllSeasonsByTeamId()
                                ])
                           )
                as function
                ,

teamId_and_playerId_injury =
        type function (      playerId  as (type text meta [
                                Documentation.FieldCaption = "playerId",
                                Documentation.AllowedValues = IterproAPIConnector.ListAllPlayersByTeamId()
                                ]),


                             injuryId as (type text meta [
                                Documentation.FieldCaption = "injuryId"
                                //Documentation.AllowedValues = IterproAPIConnector.ListAllTeamsId()
                                ])
                           )
                as function
                ,
///////////////////////////////////////////////////////////


        NavTable = (tb as table) => Table.ToNavigationTable(tb, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        table_header = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},

        lv1 = #table(
            table_header,
            {
                //{"IterproAPIConnectorGetData", "GetData", IterproAPIConnector.GetData, "function", "function", "true"},
                {"AuthController_paths", "AuthController_paths", IterproAPIConnector.AuthController_paths, "function", "function", "true"},
                {"Club. Get Club By ID", "GetClubByID", IterproAPIConnector.GetClubByID, "function", "function", "true"},
                {"Teams. List all teams", "ListAllTeams", IterproAPIConnector.ListAllTeams, "function", "function", "true"},
                {"Teams. Get team by ID", "GetTeamByID", IterproAPIConnector.GetTeamByID, "function", "function", "true"},
                {"Teams. List team injuries", "ListTeamInjuries", IterproAPIConnector.ListTeamInjuries, "function", "function", "true"},
                {"Teams. List team events", "ListTeamEvents", IterproAPIConnector.ListTeamEvents, "function", "function", "true"},
                {"Teams. List scouting players for team", "ListScoutingPlayersForTeam", IterproAPIConnector.ListScoutingPlayersForTeam, "function", "function", "true"},
                {"Teams. List team seasons", "ListTeamSeasons", IterproAPIConnector.ListTeamSeasons, "function", "function", "true"},
                {"Teams. List all team players", "ListAllTeamPlayers", IterproAPIConnector.ListAllTeamPlayers, "function", "function", "true"},
                {"Teams. Show a scouting player for team given his id", "ShowAScoutingPlayerForTeamGivenHisId", IterproAPIConnector.ShowAScoutingPlayerForTeamGivenHisId, "function", "function", "true"},
                {"Teams. Get team player by ID", "GetTeamPlayerByID", IterproAPIConnector.GetTeamPlayerByID, "function", "function", "true"},
                {"Teams. List team player thresholds", "ListTeamPlayerThresholds", IterproAPIConnector.ListTeamPlayerThresholds, "function", "function", "true"},
                {"Teams. List team player injuries", "ListTeamPlayerInjuries", IterproAPIConnector.ListTeamPlayerInjuries, "function", "function", "true"},
                {"Teams. Get team player injury", "GetTeamPlayerInjury", IterproAPIConnector.GetTeamPlayerInjury, "function", "function", "true"},
                {"Teams. List team player injury treatments", "ListTeamPlayerInjuryTreatments", IterproAPIConnector.ListTeamPlayerInjuryTreatments, "function", "function", "true"},
                {"Teams. List team player robustness data", "ListTeamPlayerRobustnessData", IterproAPIConnector.ListTeamPlayerRobustnessData, "function", "function", "true"},
                {"Teams. Get lineup for season", "GetLineupForSeason", IterproAPIConnector.GetLineupForSeason, "function", "function", "true"},

                {"Scouting. List scouting games", "ListScoutingGames", IterproAPIConnector.ListScoutingGames, "function", "function", "true"},
                {"Scouting. List scouting games for team", "ListScoutingGamesForTeam", IterproAPIConnector.ListScoutingGamesForTeam, "function", "function", "true"},
                {"Scouting. List scouting lineups for team", "ListScoutingLineupsForTeam", IterproAPIConnector.ListScoutingLineupsForTeam, "function", "function", "true"},
                {"Scouting. Show a scouting game given his id", "ShowAScoutingGameGivenHisId", IterproAPIConnector.ShowAScoutingGameGivenHisId, "function", "function", "true"},
                {"Scouting. Show a scouting game for team given his id", "ShowAScoutingGameForTeamGivenHisId", IterproAPIConnector.ShowAScoutingGameForTeamGivenHisId, "function", "function", "true"},
                {"Scouting. List scouting game reports given game id", "ListScoutingGameReportsGivenGameId", IterproAPIConnector.ListScoutingGameReportsGivenGameId, "function", "function", "true"},
                {"Scouting. List scouting game reports for team given game id", "ListScoutingGameReportsForTeamGivenGameId", IterproAPIConnector.ListScoutingGameReportsForTeamGivenGameId, "function", "function", "true"},
                {"Scouting. Show a scouting player given his id", "ShowAScoutingPlayerGivenHisId", IterproAPIConnector.ShowAScoutingPlayerGivenHisId, "function", "function", "true"},
                {"Scouting. List player attributes entry data", "ListPlayerAttributesEntryData", IterproAPIConnector.ListPlayerAttributesEntryData, "function", "function", "true"},
                {"Scouting. List player description entry data", "ListPlayerDescriptionEntryData", IterproAPIConnector.ListPlayerDescriptionEntryData, "function", "function", "true"},
                {"Scouting. List scouting players", "ListScoutingPlayers", IterproAPIConnector.ListScoutingPlayers, "function", "function", "true"},

                {"Players. List all players", "ListAllPlayers", IterproAPIConnector.ListAllPlayers, "function", "function", "true"},

                {"Players. Get player by ID",                       "GetPlayerByID",                    IterproAPIConnector.GetPlayerByID, "function", "function", "true"},
                {"Players. List player thresholds",                 "ListPlayerThresholds",             IterproAPIConnector.ListPlayerThresholds, "function", "function", "true"},
                {"Players. List player injuries",                   "ListPlayerInjuries",               IterproAPIConnector.ListPlayerInjuries, "function", "function", "true"},
                {"Players. Get player injury",                      "GetPlayerInjury",                  IterproAPIConnector.GetPlayerInjury, "function", "function", "true"},
                {"Players. List player treatments",                 "ListPlayerTreatments",             IterproAPIConnector.ListPlayerTreatments, "function", "function", "true"},
                {"Players. List player robustness data",            "ListPlayerRobustnessData",         IterproAPIConnector.ListPlayerRobustnessData, "function", "function", "true"},
                {"Players. List player injury treatments",          "ListPlayerInjuryTreatments",       IterproAPIConnector.ListPlayerInjuryTreatments, "function", "function", "true"},
                {"Players. List player attributes entry data",      "PlListPlayerAttributesEntryData",  IterproAPIConnector.PlListPlayerAttributesEntryData, "function", "function", "true"},
                {"Players. List player description entry data",     "PLListPlayerDescriptionEntryData",   IterproAPIConnector.PLListPlayerDescriptionEntryData, "function", "function", "true"}


                //{"GetCurrentCredential", "GetCurrentCredential", IterproAPIConnector.GetCurrentCredential, "function", "function", "true"}
            }
        )
    in
        NavTable(lv1);

// Data Source Kind description
IterproAPIConnector = [
    Authentication = [
        //Key = [KeyLabel = "x-iterpro-api-key"],
        UsernamePassword = [UsernameLabel = "Username", PasswordLabel = "Password"]
        //Windows = [],
        //Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
IterproAPIConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = IterproAPIConnector.Icons,
    SourceTypeImage = IterproAPIConnector.Icons
];

IterproAPIConnector.Icons = [
    Icon16 = { Extension.Contents("IterproAPIConnector16.png"), Extension.Contents("IterproAPIConnector20.png"), Extension.Contents("IterproAPIConnector24.png"), Extension.Contents("IterproAPIConnector32.png") },
    Icon32 = { Extension.Contents("IterproAPIConnector32.png"), Extension.Contents("IterproAPIConnector40.png"), Extension.Contents("IterproAPIConnector48.png"), Extension.Contents("IterproAPIConnector64.png") }
];


toTable = (lstrec as list, optional index as number, optional filds_name_sample as list) as table =>
    let
        fieldnames = 
            let
                list_combo = if filds_name_sample is null then lstrec else List.Combine( {filds_name_sample, lstrec} ),    
                toprows = if index is null then list_combo else List.FirstN(list_combo, index),
                listfields = List.Transform(toprows, Record.FieldNames),
                namesdistinct = List.Union(listfields)
            in
                namesdistinct,
        tbl = Table.FromRecords( lstrec, fieldnames, MissingField.UseNull)
    in
        tbl;



add_rec = (rec as record, recname as text, value as any) =>
    if value is null then rec else Record.AddField(rec, recname, Text.From(value));


Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
        
