#if defined _query_manager_included
	#endinput
#endif

#define _query_manager_included

#include <sqlx>

#define	QUERY_SIZE			1024

enum _: MANAGER_DATA {

	MD_NAME[32],
	MD_ADDRESS[32],
	MD_USERNAME[32],
	MD_PASSWORD[32],
	MD_DATABASE[32],
	Handle: MD_MYSQL
}

enum _: TYPE_DATA {

	TD_MANAGER_ID,
	TD_NAME[32]
}

enum _: QUERY_DATA {
	
	QD_ID,
	QD_MANAGER_ID,
	QD_TYPE_ID,
	QD_USER_ID,
	QD_USER_USERID,
	QD_QUERY[QUERY_SIZE],
	Handle: QD_MYSQL
};

/**
 * Registers a manager.
 *
 * Note: The returned manager ID will be used later.
 *
 * @param name			Name of the manager.
 * @param address		Mysql address.
 * @param username		Mysql username.
 * @param password		Mysql password.
 * @param database		Mysql database.
 *
 * @return				An internal manager ID.
 */
native qm_register_manager(name[], address[] = "127.0.0.1", username[] = "root", password[] = "", database[] = "mysql");

/**
 * Registers a type.
 *
 * Note: The returned type ID will be used later.
 * Use 0 for manager_id to use the default one.
 *
 * @param manager_id	Manager ID.
 * @param address		Name of the type.
 *
 * @return				An internal type ID.
 */
native qm_register_type(manager_id = 0, name[]);

/**
 * Create a query will be send in a manager's type.
 *
 * @param type_id		Type ID.
 * @param query			Query message.
 * @param user_id		Player UID (NOT the Player ID. Use: get_user_userid(id)) or 0.
 *
 * @return				Query ID from the current session.
 */
native qm_create_query(type_id, query[], user_id = 0);

/**
 * Returns if all queries from the previous map are completed.
 *
 * @return				True if completed, false otherwise.
 */
native qm_is_preload_completed();

/**
 * Called when a query is compelted.
 *
 * @param query_data	The buffer to store the query's data in.
 */
forward fw_Query_Completed(query_data[QUERY_DATA]);

/**
 * Called when queries of a specific manager from the previous map are completed.
 *
 * @param manager_id	A manager ID.
 */
forward fw_Preload_Completed(manager_id);