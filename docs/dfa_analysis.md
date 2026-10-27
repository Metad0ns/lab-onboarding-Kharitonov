# Def-Use цепочки функции process_transaction

Нумерация строк: строка 1 – `def process_transaction(...)`, пустые строки
тоже считаются.

## Переменная: log_entry
- Def: строка 2 (`log_entry = "Start processing"`)
- Def: строка 10 (`log_entry = "Transaction finished with status: " + status`)
- Use: строка 13 (`file.write(log_entry)`)
- Примечание: определение на строке 2 перекрывается определением на
  строке 10 до первого использования, поэтому оно «мертвое».

## Переменная: status
- Def: строка 5 (`status = "approved"`), выполняется только при `amount > 0`
- Use: строка 10 (использование в конкатенации строки)
- Use: строка 15 (`return status`)
- Примечание: при `amount <= 0` путь со строки 4 на строку 10 не проходит
  через def, поэтому переменная не инициализирована.

## Переменная: balance
- Def: строка 6 (`balance = get_balance(user_id)`)
- Use: строка 7 (`new_balance = balance - amount`)

## Переменная: new_balance
- Def: строка 7 (`new_balance = balance - amount`)
- Use: строка 8 (`update_balance(user_id, new_balance)`)

## Переменная: file
- Def: строка 12 (`file = open("audit_log.txt", "w")`)
- Use: строка 13 (`file.write(log_entry)`)
- Примечание: вызова `file.close()` нет, ресурс не освобождается.

## Параметры функции
- `user_id`: def в сигнатуре (строка 1), use в строках 6 и 8.
- `amount`: def в сигнатуре, use в строках 4 и 7.
- `db_connection`: def в сигнатуре, нигде не используется (лишний параметр).
