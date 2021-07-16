/*

    » Basic UCP SA:MP Roleplay Gamemode
    
    » Credits: - Kalcor
			   - Y_Less
			   - pBlueG
			   - ZeeX
			   - Yashas
			   - SyS
			   - LuminouZ
			   
    » NOTE: Please don't remove the credits!
    
	===== » V1 Changelog =====
	
	» Added Login & Register
	
	==========================
    
*/

/* Includes */
#include <a_samp>
#include <a_mysql>
#include <YSI_Coding\y_va>
#include <foreach>
#include <samp_bcrypt>
#include <izcmd>

/* Define & Macro */

#define FUNC::%0(%1) forward %0(%1); public %0(%1)

#define COLOR_YELLOW 0xFFFF00FF

#define SendMessage(%0,%1) \
	SendClientMessageEx(%0, COLOR_YELLOW, "»{FFFFFF} "%1)
	
#define MAX_CHARS 3

#define DATABASE_ADDRESS "localhost" //Change this to your Database Address
#define DATABASE_USERNAME "root" // Change this to your database username
#define DATABASE_PASSWORD "" //Change this to your database password
#define DATABASE_NAME "basicrp" // Change this to your database name

#if !defined BCRYPT_HASH_LENGTH
	#define BCRYPT_HASH_LENGTH 250
#endif

#if !defined BCRYPT_COST
	#define BCRYPT_COST 12
#endif

/* Variable */

new MySQL:sqlcon;
new g_RaceCheck[MAX_PLAYERS char];
new PlayerChar[MAX_PLAYERS][MAX_CHARS][MAX_PLAYER_NAME + 1];
new tempUCP[64];

/* Enums */

enum
{
	DIALOG_REGISTER,
	DIALOG_LOGIN,
	DIALOG_MAKECHAR,
	DIALOG_ORIGIN,
	DIALOG_AGE,
	DIALOG_GENDER,
	DIALOG_CHARLIST,
};

enum e_player_data
{
	pID,
	pUCP[22],
	pName[MAX_PLAYER_NAME],
	Float:pPos[3],
	pWorld,
	pInterior,
	pSkin,
	pAge,
	pOrigin[32],
	pGender,
	bool:pSpawned,
	pChar,
	Float:pHealth,
};

new PlayerData[MAX_PLAYERS][e_player_data];

/* Functions */

stock GetName(playerid)
{
	new name[MAX_PLAYER_NAME];
 	GetPlayerName(playerid,name,sizeof(name));
	return name;
}

Database_Connect()
{
	sqlcon = mysql_connect(DATABASE_ADDRESS,DATABASE_USERNAME,DATABASE_PASSWORD,DATABASE_NAME);

	if(mysql_errno(sqlcon) != 0){
	    print("[MySQL] - Connection Failed!");
	}
	else{
		print("[MySQL] - Connection Estabilished!");
	}
}

stock IsRoleplayName(player[])
{
    for(new n = 0; n < strlen(player); n++)
    {
        if (player[n] == '_' && player[n+1] >= 'A' && player[n+1] <= 'Z') return 1;
        if (player[n] == ']' || player[n] == '[') return 0;
	}
    return 0;
}

stock IsPlayerNearPlayer(playerid, targetid, Float:radius)
{
	static
		Float:fX,
		Float:fY,
		Float:fZ;

	GetPlayerPos(targetid, fX, fY, fZ);

	return (GetPlayerInterior(playerid) == GetPlayerInterior(targetid) && GetPlayerVirtualWorld(playerid) == GetPlayerVirtualWorld(targetid)) && IsPlayerInRangeOfPoint(playerid, radius, fX, fY, fZ);
}

stock SendNearbyMessage(playerid, Float:radius, color, const str[], {Float,_}:...)
{
	static
	    args,
	    start,
	    end,
	    string[144]
	;
	#emit LOAD.S.pri 8
	#emit STOR.pri args

	if (args > 16)
	{
		#emit ADDR.pri str
		#emit STOR.pri start

	    for (end = start + (args - 16); end > start; end -= 4)
		{
	        #emit LREF.pri end
	        #emit PUSH.pri
		}
		#emit PUSH.S str
		#emit PUSH.C 144
		#emit PUSH.C string

		#emit LOAD.S.pri 8
		#emit CONST.alt 4
		#emit SUB
		#emit PUSH.pri

		#emit SYSREQ.C format
		#emit LCTRL 5
		#emit SCTRL 4

        foreach (new i : Player)
		{
			if (IsPlayerNearPlayer(i, playerid, radius) && PlayerData[i][pSpawned])
			{
  				SendClientMessage(i, color, string);
			}
		}
		return 1;
	}
	foreach (new i : Player)
	{
		if (IsPlayerNearPlayer(i, playerid, radius) && PlayerData[i][pSpawned])
		{
			SendClientMessage(i, color, str);
		}
	}
	return 1;
}

stock SendClientMessageEx(playerid, colour, const text[], va_args<>)
{
    new str[145];
    va_format(str, sizeof(str), text, va_start<3>);
    return SendClientMessage(playerid, colour, str);
}

stock CheckAccount(playerid)
{
	new query[256];
	format(query, sizeof(query), "SELECT * FROM `PlayerUCP` WHERE `UCP` = '%s' LIMIT 1;", GetName(playerid));
	mysql_tquery(sqlcon, query, "CheckPlayerUCP", "d", playerid);
	return 1;
}

FUNC::PlayerCheck(playerid, rcc)
{
	if(rcc != g_RaceCheck{playerid})
	    return Kick(playerid);
	    
	CheckAccount(playerid);
	return true;
}

FUNC::CheckPlayerUCP(playerid)
{
	new rows = cache_num_rows();
	new str[256];
	if (rows)
	{
	    cache_get_value_name(0, "UCP", tempUCP[playerid]);
	    format(str, sizeof(str), "Welcome Back to Roleplay Server!\n\nYour UCP: %s\nPlease insert your Password below to logged in:", GetName(playerid));
		ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "UCP - Login", str, "Login", "Exit");
	}
	else
	{
	    format(str, sizeof(str), "Welcome to Roleplay Server!\n\nYour UCP: %s\nPlease insert your Password below to register:", GetName(playerid));
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "UCP - Register", str, "Register", "Exit");
	}
	return 1;
}

stock SetupPlayerData(playerid)
{
    SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin], 1642.1681, -2333.3689, 13.5469, 0.0, 0, 0, 0, 0, 0, 0);
    SpawnPlayer(playerid);
    return 1;
}

stock SaveData(playerid)
{
	new query[1012];
	if(PlayerData[playerid][pSpawned])
	{
		GetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
		GetPlayerPos(playerid, PlayerData[playerid][pPos][0], PlayerData[playerid][pPos][1], PlayerData[playerid][pPos][2]);

	    format(query, sizeof(query), "UPDATE `characters` SET `PosX` = '%.4f', `PosY` = '%.4f', `PosZ` = '%.4f', `Health` = '%.4f', `World` = '%d', `Interior` = '%d', `Age` = '%d', `Origin` = '%s', `Gender` = '%d', `Skin` = '%d', `UCP` = '%s' WHERE `pID`= '%d'",
			PlayerData[playerid][pPos][0],
			PlayerData[playerid][pPos][1],
			PlayerData[playerid][pPos][2],
			PlayerData[playerid][pHealth],
			GetPlayerVirtualWorld(playerid),
			GetPlayerInterior(playerid),
			PlayerData[playerid][pAge],
			PlayerData[playerid][pOrigin],
			PlayerData[playerid][pGender],
			PlayerData[playerid][pSkin],
			PlayerData[playerid][pUCP],
			PlayerData[playerid][pID]
		);
		mysql_tquery(sqlcon, query);
	}
	return 1;
}

FUNC::LoadCharacterData(playerid)
{
	cache_get_value_name_int(0, "pID", PlayerData[playerid][pID]);
	cache_get_value_name(0, "Name", PlayerData[playerid][pName]);
	cache_get_value_name_float(0, "PosX", PlayerData[playerid][pPos][0]);
	cache_get_value_name_float(0, "PosY", PlayerData[playerid][pPos][1]);
	cache_get_value_name_float(0, "PosZ", PlayerData[playerid][pPos][2]);
	cache_get_value_name_float(0, "Health", PlayerData[playerid][pHealth]);
	cache_get_value_name_int(0, "Interior", PlayerData[playerid][pInterior]);
	cache_get_value_name_int(0, "World", PlayerData[playerid][pWorld]);
	cache_get_value_name_int(0, "Age", PlayerData[playerid][pAge]);
	cache_get_value_name(0, "Origin", PlayerData[playerid][pOrigin]);
	cache_get_value_name_int(0, "Gender", PlayerData[playerid][pGender]);
	cache_get_value_name_int(0, "Skin", PlayerData[playerid][pSkin]);
	cache_get_value_name(0, "UCP", PlayerData[playerid][pUCP]);
	
    SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin], PlayerData[playerid][pPos][0], PlayerData[playerid][pPos][1], PlayerData[playerid][pPos][2], 0.0, 0, 0, 0, 0, 0, 0);
    SpawnPlayer(playerid);
    SendMessage(playerid, "Successfully loaded your characters database!");
    return 1;
}

FUNC::HashPlayerPassword(playerid, hashid)
{
	new
		query[256],
		hash[BCRYPT_HASH_LENGTH];

    bcrypt_get_hash(hash, sizeof(hash));

	GetPlayerName(playerid, tempUCP[playerid], MAX_PLAYER_NAME + 1);

	format(query,sizeof(query),"INSERT INTO `PlayerUCP` (`UCP`, `Password`) VALUES ('%s', '%s')", tempUCP[playerid], hash);
	mysql_tquery(sqlcon, query);

    SendMessage(playerid, "Your UCP is successfully registered!");
    CheckAccount(playerid);
	return 1;
}

ShowCharacterList(playerid)
{
	new name[256], count, sgstr[128];

	for (new i; i < MAX_CHARS; i ++) if(PlayerChar[playerid][i][0] != EOS)
	{
	    format(sgstr, sizeof(sgstr), "%s\n", PlayerChar[playerid][i]);
		strcat(name, sgstr);
		count++;
	}
	if(count < MAX_CHARS)
		strcat(name, "< Create Character >");

	ShowPlayerDialog(playerid, DIALOG_CHARLIST, DIALOG_STYLE_LIST, "Character List", name, "Select", "Quit");
	return 1;
}

FUNC::LoadCharacter(playerid)
{
	for (new i = 0; i < MAX_CHARS; i ++)
	{
		PlayerChar[playerid][i][0] = EOS;
	}
	for (new i = 0; i < cache_num_rows(); i ++)
	{
		cache_get_value_name(i, "Name", PlayerChar[playerid][i]);
	}
  	ShowCharacterList(playerid);
  	return 1;
}

FUNC::OnPlayerPasswordChecked(playerid, bool:success)
{
	new str[256];
    format(str, sizeof(str), "Welcome Back to Roleplay Server!\n\nYour UCP: %s\nPlease insert your Password below to logged in:", GetName(playerid));
    
	if(!success)
        return ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "UCP - Login", str, "Login", "Exit");

	new query[256];
	format(query, sizeof(query), "SELECT `Name` FROM `characters` WHERE `UCP` = '%s' LIMIT %d;", GetName(playerid), MAX_CHARS);
	mysql_tquery(sqlcon, query, "LoadCharacter", "d", playerid);
	return 1;
}

FUNC::InsertPlayerName(playerid, name[])
{
	new count = cache_num_rows(), query[145], Cache:execute;
	if(count > 0)
	{
        ShowPlayerDialog(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "ERROR: This name is already used by the other player!\nInsert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Back");
	}
	else
	{
		mysql_format(sqlcon,query,sizeof(query),"INSERT INTO `characters` (`Name`,`UCP`) VALUES('%e','%e')",name,GetName(playerid));
		execute = mysql_query(sqlcon, query);
		PlayerData[playerid][pID] = cache_insert_id();
	 	cache_delete(execute);
	 	SetPlayerName(playerid, name);
		format(PlayerData[playerid][pName], MAX_PLAYER_NAME, name);
	 	ShowPlayerDialog(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "Please Insert your Character Age", "Continue", "Cancel");
	}
	return 1;
}

/* Gamemode Start! */

main()
{
	print("UCP Roleplay Gamemode loaded!");
}

public OnGameModeInit()
{
	Database_Connect();
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerConnect(playerid)
{
	g_RaceCheck{playerid} ++;
	SetPlayerPos(playerid, 155.3337, -1776.4384, 14.8978+5.0);
	SetPlayerCameraPos(playerid, 155.3337, -1776.4384, 14.8978);
	SetPlayerCameraLookAt(playerid, 156.2734, -1776.0850, 14.2128);
	InterpolateCameraLookAt(playerid, 156.2734, -1776.0850, 14.2128, 156.2713, -1776.0797, 14.7078, 5000, CAMERA_MOVE);
	SetTimerEx("PlayerCheck", 1000, false, "ii", playerid, g_RaceCheck{playerid});
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SaveData(playerid);
	return 1;
}
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(dialogid == DIALOG_REGISTER)
	{
	    if(!response)
	        return Kick(playerid);

		new str[256];
	    format(str, sizeof(str), "Welcome to Roleplay Server!\n\nYour UCP: %s\nERROR: Password length cannot below 7 or above 32!\nPlease insert your Password below to register:", GetName(playerid));

        if(strlen(inputtext) < 7)
			return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "UCP - Register", str, "Register", "Exit");

        if(strlen(inputtext) > 32)
			return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "UCP - Register", str, "Register", "Exit");

        bcrypt_hash(playerid, "HashPlayerPassword", inputtext, BCRYPT_COST);
	}
	if(dialogid == DIALOG_LOGIN)
	{
	    if(!response)
	        return Kick(playerid);
	        
        if(strlen(inputtext) < 1)
        {
			new str[256];
            format(str, sizeof(str), "Welcome Back to Roleplay Server!\n\nYour UCP: %s\nPlease insert your Password below to logged in:", GetName(playerid));
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "UCP - Login", str, "Login", "Exit");
            return 1;
		}
		new pwQuery[256], hash[BCRYPT_HASH_LENGTH];
		mysql_format(sqlcon, pwQuery, sizeof(pwQuery), "SELECT Password FROM PlayerUCP WHERE UCP = '%e' LIMIT 1", GetName(playerid));
		mysql_query(sqlcon, pwQuery);
		
        cache_get_value_name(0, "Password", hash, sizeof(hash));
        
        bcrypt_verify(playerid, "OnPlayerPasswordChecked", inputtext, hash);

	}
    if(dialogid == DIALOG_CHARLIST)
    {
		if(response)
		{
			if (PlayerChar[playerid][listitem][0] == EOS)
				return ShowPlayerDialog(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Exit");

			PlayerData[playerid][pChar] = listitem;
			SetPlayerName(playerid, PlayerChar[playerid][listitem]);

			new cQuery[256];
			mysql_format(sqlcon, cQuery, sizeof(cQuery), "SELECT * FROM `characters` WHERE `Name` = '%s' LIMIT 1;", PlayerChar[playerid][PlayerData[playerid][pChar]]);
			mysql_tquery(sqlcon, cQuery, "LoadCharacterData", "d", playerid);
			
		}
	}
	if(dialogid == DIALOG_MAKECHAR)
	{
	    if(response)
	    {
		    if(strlen(inputtext) < 1 || strlen(inputtext) > 24)
				return ShowPlayerDialog(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Back");

			if(!IsRoleplayName(inputtext))
				return ShowPlayerDialog(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Back");

			new characterQuery[178];
			mysql_format(sqlcon, characterQuery, sizeof(characterQuery), "SELECT * FROM `characters` WHERE `Name` = '%s'", inputtext);
			mysql_tquery(sqlcon, characterQuery, "InsertPlayerName", "ds", playerid, inputtext);

		    format(PlayerData[playerid][pUCP], 22, GetName(playerid));
		}
	}
	if(dialogid == DIALOG_AGE)
	{
		if(response)
		{
			if(strval(inputtext) >= 70)
			    return ShowPlayerDialog(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "ERROR: Cannot more than 70 years old!", "Continue", "Cancel");

			if(strval(inputtext) < 13)
			    return ShowPlayerDialog(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "ERROR: Cannot below 13 Years Old!", "Continue", "Cancel");

			PlayerData[playerid][pAge] = strval(inputtext);
			ShowPlayerDialog(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");
		}
		else
		{
		    ShowPlayerDialog(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "Please Insert your Character Age", "Continue", "Cancel");
		}
	}
	if(dialogid == DIALOG_ORIGIN)
	{
	    if(!response)
	        return ShowPlayerDialog(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");

		if(strlen(inputtext) < 1)
		    return ShowPlayerDialog(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");

        format(PlayerData[playerid][pOrigin], 32, inputtext);
        ShowPlayerDialog(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Character Gender", "Male\nFemale", "Continue", "Cancel");
	}
	if(dialogid == DIALOG_GENDER)
	{
	    if(!response)
	        return ShowPlayerDialog(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Character Gender", "Male\nFemale", "Continue", "Cancel");

		if(listitem == 0)
		{
			PlayerData[playerid][pGender] = 1;
			PlayerData[playerid][pSkin] = 240;
			PlayerData[playerid][pHealth] = 100.0;
			SetupPlayerData(playerid);
		}
		if(listitem == 1)
		{
			PlayerData[playerid][pGender] = 1;
			PlayerData[playerid][pSkin] = 172;
			PlayerData[playerid][pHealth] = 100.0;
			SetupPlayerData(playerid);
		}
	}
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(!PlayerData[playerid][pSpawned])
	{
	    PlayerData[playerid][pSpawned] = true;
	    SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
	    SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
	    SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
		SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
	}
	return 1;
}


public OnPlayerText(playerid, text[])
{
	SendNearbyMessage(playerid, 20.0, -1, "%s says: %s", GetName(playerid), text);
    return 0;
}
/* » Commands */
CMD:stats(playerid, params[])
{
	if(!PlayerData[playerid][pSpawned])
	    return SendMessage(playerid, "You're not spawned!");
	    
	SendMessage(playerid, "UCP: %s", PlayerData[playerid][pUCP]);
	SendMessage(playerid, "Name: %s", GetName(playerid));
	SendMessage(playerid, "Age: %d", PlayerData[playerid][pAge]);
	SendMessage(playerid, "Gender: %s", (PlayerData[playerid][pGender] == 2) ? ("Female") : ("Male"));
	SendMessage(playerid, "Origin: %s", PlayerData[playerid][pOrigin]);
	return 1;
}

