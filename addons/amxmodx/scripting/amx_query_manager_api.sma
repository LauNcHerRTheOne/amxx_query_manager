#include <amxmodx>
#include <amxmisc>
#include <query_manager>

#define LOG_FILE					"query_manager.log"
#define	SQL_FILE					"queries.txt"

enum _:CVS {

	CV_LOG,
	CV_DELAY,
	CV_NAME,
	CV_ADDRESS,
	CV_USER,
	CV_PASS,
	CV_DB
};

new g_file[256], Array: g_managers, Array: g_types, Array: g_queries, g_query_id, bool: g_query_send, g_preload;
new Trie: g_manager_ids, Trie: g_type_ids, g_console_variables[CVS];
new g_forward_query, g_forward_preload, g_forward_result, bool: g_plugin_end;

public plugin_init() {

	register_plugin("Query Manager API", "1.0.0", "JohanCorn");

	g_managers = ArrayCreate(MANAGER_DATA);
	g_types = ArrayCreate(TYPE_DATA);
	g_queries = ArrayCreate(QUERY_DATA);

	g_manager_ids = TrieCreate();
	g_type_ids = TrieCreate();

	g_forward_query = CreateMultiForward("fw_Query_Completed", ET_IGNORE, FP_ARRAY);
	g_forward_preload = CreateMultiForward("fw_Preload_Completed", ET_IGNORE);

	get_datadir(g_file, charsmax(g_file));
	add(g_file, charsmax(g_file), "/query_manager/");

	if ( !dir_exists(g_file) )
		mkdir(g_file);

	g_console_variables[CV_LOG] = register_cvar("amx_qm_log", "2");
	g_console_variables[CV_DELAY] = register_cvar("amx_qm_delay", "5.0");
	g_console_variables[CV_NAME] = register_cvar("amx_dqm_name", "default_manager");
	g_console_variables[CV_ADDRESS] = register_cvar("amx_dqm_address", "127.0.0.1");
	g_console_variables[CV_USER] = register_cvar("amx_dqm_user", "root");
	g_console_variables[CV_PASS] = register_cvar("amx_dqm_pass", "");
	g_console_variables[CV_DB] = register_cvar("amx_dqm_db", "cstrike");
}

public plugin_cfg() {

	AutoExecConfig();

	set_task(0.5, "def");
}

public def() {

	new manager_data[MANAGER_DATA];

	get_pcvar_string(g_console_variables[CV_NAME], manager_data[MD_NAME], charsmax(manager_data[MD_NAME]));
	get_pcvar_string(g_console_variables[CV_ADDRESS], manager_data[MD_ADDRESS], charsmax(manager_data[MD_ADDRESS]));
	get_pcvar_string(g_console_variables[CV_USER], manager_data[MD_USERNAME], charsmax(manager_data[MD_USERNAME]));
	get_pcvar_string(g_console_variables[CV_PASS], manager_data[MD_PASSWORD], charsmax(manager_data[MD_PASSWORD]));
	get_pcvar_string(g_console_variables[CV_DB], manager_data[MD_DATABASE], charsmax(manager_data[MD_DATABASE]));

	register_manager(manager_data);

	for ( new i; i < ArraySize(g_managers); i ++ ) {

		ArrayGetArray(g_managers, i, manager_data);
		manager_data[MD_MYSQL] = SQL_MakeDbTuple(manager_data[MD_ADDRESS], manager_data[MD_USERNAME], manager_data[MD_PASSWORD], manager_data[MD_DATABASE]);
		ArraySetArray(g_managers, i, manager_data);
	}

	load_queries_from_file();
}

public plugin_natives() {

	register_library("query_manager");

	register_native("qm_register_manager", "native_register_manager");
	register_native("qm_register_type", "native_register_type");
	register_native("qm_create_query", "native_create_query");
	register_native("qm_is_preload_completed", "native_is_preload_completed");
}

public plugin_end() {

	g_plugin_end = true;
}

public native_register_manager() {

	new manager_data[MANAGER_DATA];
	get_string(1, manager_data[MD_NAME], charsmax(manager_data[MD_NAME]));
	get_string(2, manager_data[MD_ADDRESS], charsmax(manager_data[MD_ADDRESS]));
	get_string(3, manager_data[MD_USERNAME], charsmax(manager_data[MD_USERNAME]));
	get_string(4, manager_data[MD_PASSWORD], charsmax(manager_data[MD_PASSWORD]));
	get_string(5, manager_data[MD_DATABASE], charsmax(manager_data[MD_DATABASE]));

	return register_manager(manager_data);
}

public native_register_type() {

	static name[32];
	get_string(2, name, charsmax(name));
	
	new type_id = register_type(get_param(1), name);

	TrieSetCell(g_type_ids, name, type_id);

	return type_id;
}

public native_create_query() {

	new query[QUERY_SIZE];
	get_string(2, query, charsmax(query));

	return create_query(get_param(1), query, get_param(3));
}

public native_is_preload_completed() {

	return is_preload_completed();
}

public load_queries_from_file() {
	
	static sql_file_path[128];
	get_sql_file_path(sql_file_path, charsmax(sql_file_path));

	new file = fopen(sql_file_path, "rt");
	static data[QUERY_SIZE + 128], data_left[64], query[QUERY_SIZE], manager_name[32], type_name[32], type_id

	while ( !feof(file) ) {
		
		fgets(file, data, charsmax(data));
		
		if ( data[0] == EOS )
			continue;

		strtok2(data, data_left, charsmax(data_left), query, charsmax(query));
		strtok2(data_left, manager_name, charsmax(manager_name), type_name, charsmax(type_name), '.');

		if ( TrieKeyExists(g_manager_ids, manager_name) && TrieGetCell(g_type_ids, type_name, type_id) )
			g_preload = create_query(type_id, query, 0);
	}

	fclose(file);

	if ( !g_preload )
		ExecuteForward(g_forward_preload, g_forward_result);

	send_first_query_if_exists();

	return g_preload;
}

public save_queries_to_file() {

	static sql_file_path[128];
	get_sql_file_path(sql_file_path, charsmax(sql_file_path));

	if ( file_exists(sql_file_path) )
		delete_file(sql_file_path);
	
	new file = fopen(sql_file_path, "wt");
 
	static data[QUERY_SIZE + 128], query_data[QUERY_DATA], manager_data[MANAGER_DATA], type_data[TYPE_DATA];

	for ( new i; i < ArraySize(g_queries); i ++ ) {

		ArrayGetArray(g_queries, i, query_data);
		ArrayGetArray(g_types, query_data[QD_TYPE_ID], type_data);
		ArrayGetArray(g_managers, type_data[TD_MANAGER_ID], manager_data);
		formatex(data, charsmax(data), "%s.%s %s^n", manager_data[MD_NAME], type_data[TD_NAME], query_data[QD_QUERY]);
		fputs(file, data);
	}
 
	fclose(file);
}

public register_manager(manager_data[]) {

	static manager_id; manager_id = ArrayPushArray(g_managers, manager_data);

	TrieSetCell(g_manager_ids, manager_data[MD_NAME], manager_id);

	return manager_id;
}

public register_type(manager_id, name[]) {

	static type_data[TYPE_DATA];
	type_data[TD_MANAGER_ID] = manager_id;
	copy(type_data[TD_NAME], charsmax(type_data[TD_NAME]), name);

	return ArrayPushArray(g_types, type_data);
}

public create_query(type_id, query[], user_id) {
	
	static type_data[TYPE_DATA];
	ArrayGetArray(g_types, type_id, type_data);

	static query_data[QUERY_DATA];
	copy(query_data[QD_QUERY], charsmax(query_data[QD_QUERY]), query);
	query_data[QD_ID] = ++ g_query_id;
	query_data[QD_MANAGER_ID] = type_data[TD_MANAGER_ID];
	query_data[QD_TYPE_ID] = type_id;
	query_data[QD_USER_ID] = user_id;
	query_data[QD_USER_USERID] = get_user_userid(user_id);
	ArrayPushArray(g_queries, query_data);

	if ( get_pcvar_num(g_console_variables[CV_LOG]) >= 2 ) {

		static name[64];
		get_query_name(type_id, name, charsmax(name));

		log_to_file(LOG_FILE, "%i. Thread Query: ^"%s^" | CREATE!", query_data[QD_ID], name);

		if ( get_pcvar_num(g_console_variables[CV_LOG]) >= 3 )
			log_to_file(LOG_FILE, "%i. Thread Query: %s", query_data[QD_ID], query);
	}

	save_queries_to_file();
	send_first_query_if_exists();

	return query_data[QD_ID];
}

public send_first_query_if_exists() {

	if ( g_plugin_end )
		return;

	if ( g_query_send )
		return;

	if ( !ArraySize(g_queries) )
		return;

	g_query_send = true;

	static query_data[QUERY_DATA];
	ArrayGetArray(g_queries, 0, query_data);

	static manager_data[MANAGER_DATA];
	ArrayGetArray(g_managers, query_data[QD_MANAGER_ID], manager_data);

	SQL_ThreadQuery(manager_data[MD_MYSQL], "query_callback", query_data[QD_QUERY], query_data, sizeof(query_data));

	if ( get_pcvar_num(g_console_variables[CV_LOG]) < 2 )
		return;

	static name[64];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	log_to_file(LOG_FILE, "%i. Thread Query: ^"%s^" | START!", query_data[QD_ID], name);
}

public query_callback(fail_state, Handle: query, error[], error_code, query_data[], size) {

	g_query_send = false;

	if ( !error_code )
	 	query_set_completed(query, query_data);
	else
		query_set_failed(query, query_data, error, error_code);
}

public query_set_failed(Handle: query, query_data[], error[], error_code) {
	
	static name[64];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	if ( get_pcvar_num(g_console_variables[CV_LOG]) >= 1 ) {

		log_to_file(LOG_FILE, "%i. Thread Query: ^"%s^" | FAILED!", query_data[QD_ID], name);
		log_to_file(LOG_FILE, "%i. Error: %s", query_data[QD_ID], error);
	}
	
	set_task(get_pcvar_float(g_console_variables[CV_DELAY]), "send_first_query_if_exists");
}

public query_set_completed(Handle: query, query_data[]) {

	query_data[QD_MYSQL] = query;

	ArrayDeleteItem(g_queries, 0);

	static name[64];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	if ( get_pcvar_num(g_console_variables[CV_LOG]) >= 2 )
		log_to_file(LOG_FILE, "%i. Thread Query: ^"%s^" | COMPLETED!", query_data[QD_ID], name);

	ExecuteForward(g_forward_query, g_forward_result, PrepareArray(query_data, QUERY_DATA, 0));

	if ( is_preload_completed() )
		ExecuteForward(g_forward_preload, g_forward_result);

	save_queries_to_file();
	send_first_query_if_exists();
}

public is_preload_completed() {

	return !g_preload;
}

public get_sql_file_path(path[], len) {

	copy(path, len, g_file);
	add(path, len, SQL_FILE);
}

public get_query_name(type_id, name[], len) {

	static manager_data[MANAGER_DATA], type_data[TYPE_DATA];
	ArrayGetArray(g_types, type_id, type_data);
	ArrayGetArray(g_managers, type_data[TD_MANAGER_ID], manager_data);

	copy(name, len, manager_data[MD_NAME]);
	add(name, len, ".");
	add(name, len, type_data[TD_NAME]);
}