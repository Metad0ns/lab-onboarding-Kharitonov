def get_balance(user_id):
    return 1000


def update_balance(user_id, new_balance):
    return None


def process_transaction(user_id, amount, db_connection):
    status = "pending"
    balance = get_balance(user_id)

    if amount > 0 and amount <= balance:
        status = "approved"
        new_balance = balance - amount
        update_balance(user_id, new_balance)
    else:
        status = "declined"

    log_entry = f"Transaction finished with status: {status}\n"

    with open("audit_log.txt", "a", encoding="utf-8") as file:
        file.write(log_entry)

    return status
