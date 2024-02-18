# Смарт контракт токена на языке Cairo
# Он позволяет создавать, переводить и сжигать токены
# Он использует стандартный интерфейс ERC20

# Импортируем необходимые библиотеки
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_check

# Определяем константы
# Название токена
const TOKEN_NAME = 'Cairo Token'
# Символ токена
const TOKEN_SYMBOL = 'CTK'
# Количество десятичных знаков
const TOKEN_DECIMALS = 18
# Общее количество токенов
const TOKEN_TOTAL_SUPPLY = 10**9 * 10**TOKEN_DECIMALS

# Определяем структуру состояния смарт контракта
struct State:
    # Хэш состояния
    hash_ptr: HashBuiltin*
    # Словарь балансов токенов
    balances: DictAccess*
    # Словарь разрешений на перевод токенов
    allowances: DictAccess*
end

# Определяем функцию инициализации смарт контракта
func token_init{hash_ptr : HashBuiltin*, balances : DictAccess*, allowances : DictAccess*}() -> (State*):
    let (fp, _) = get_fp_and_pc()
    # Создаем структуру состояния
    let state_ptr = cast(fp + 1, State*)
    # Устанавливаем хэш состояния
    state_ptr.hash_ptr = hash_ptr
    # Устанавливаем словарь балансов
    state_ptr.balances = balances
    # Устанавливаем словарь разрешений
    state_ptr.allowances = allowances
    # Выдаем все токены создателю смарт контракта
    let creator_address = fp - 3
    balances.write(creator_address, TOKEN_TOTAL_SUPPLY)
    # Обновляем хэш состояния
    let hash = hash_init()
    hash = hash_update(hash, creator_address)
    hash = hash_update(hash, TOKEN_TOTAL_SUPPLY)
    hash_ptr.write(hash_finalize(hash))
    return (state_ptr)
end

# Определяем функцию получения названия токена
func token_name{state_ptr : State*}() -> ():
    # Возвращаем название токена
    return (TOKEN_NAME)
end

# Определяем функцию получения символа токена
func token_symbol{state_ptr : State*}() -> ():
    # Возвращаем символ токена
    return (TOKEN_SYMBOL)
end

# Определяем функцию получения количества десятичных знаков
func token_decimals{state_ptr : State*}() -> ():
    # Возвращаем количество десятичных знаков
    return (TOKEN_DECIMALS)
end

# Определяем функцию получения общего количества токенов
func token_total_supply{state_ptr : State*}() -> ():
    # Возвращаем общее количество токенов
    return (TOKEN_TOTAL_SUPPLY)
end

# Определяем функцию получения баланса токенов по адресу
func token_balance_of{state_ptr : State*}(address : felt) -> ():
    # Проверяем, что адрес валидный
    uint256_check(address)
    # Читаем баланс из словаря
    let balance = state_ptr.balances.read(address)
    # Возвращаем баланс
    return (balance)
end

# Определяем функцию перевода токенов с одного адреса на другой
func token_transfer{state_ptr : State*}(to : felt, value : Uint256) -> ():
    # Проверяем, что адреса валидные
    uint256_check(to)
    # Получаем адрес отправителя из стека вызовов
    let from = fp - 3
    # Проверяем, что сумма перевода валидная
    uint256_check(value)
    # Читаем балансы отправителя и получателя из словаря
    let from_balance = state_ptr.balances.read(from)
    let to_balance = state_ptr.balances.read(to)
    # Вычитаем сумму перевода из баланса отправителя
    let (new_from_balance, is_overflow) = uint256_add(from_balance, -value)
    # Проверяем, что у отправителя достаточно токенов
    assert_not_zero(is_overflow == 0)
    # Прибавляем сумму перевода к балансу получателя
    let (new_to_balance, is_overflow) = uint256_add(to_balance, value)
    # Проверяем, что не произошло переполнения
    assert_not_zero(is_overflow == 0)
    # Записываем новые балансы в словарь
    state_ptr.balances.write(from, new_from_balance)
    state_ptr.balances.write(to, new_to_balance)
    # Обновляем хэш состояния
    let hash = hash_init()
    hash = hash_update(hash, from)
    hash = hash_update(hash, new_from_balance)
    hash = hash_update(hash, to)
    hash = hash_update(hash, new_to_balance)
    state_ptr.hash_ptr.write(hash_finalize(hash))
    # Возвращаем успешный результат
    return (1)
end

# Определяем функцию получения разрешения на перевод токенов от одного адреса к другому
func token_allowance{state_ptr : State*}(owner : felt, spender : felt) -> ():
    # Проверяем, что адреса валидные
    uint256_check(owner)
    uint256_check(spender)
    # Читаем разрешение из словаря
    let allowance = state_ptr.allowances.read(owner, spender)
    # Возвращаем разрешение
    return (allowance)
end

# Определяем функцию установки разрешения на перевод токенов от одного адреса к другому
func token_approve{state_ptr : State*}(spender : felt, value : Uint256) -> ():
    # Проверяем, что адреса валидные
    uint256_check(spender)
    # Получаем адрес владельца из стека вызовов
    let owner = fp - 3
    # Проверяем, что сумма разрешения валидная
    uint256_check(value)
    # Записываем разрешение в словарь
    state_ptr.allowances.write(owner, spender, value)
    # Обновляем хэш состояния
    let hash = hash_init()
    hash = hash_update(hash, owner)
    hash = hash_update(hash, spender)
    hash = hash_update(hash, value)
    state_ptr.hash_ptr.write(hash_finalize(hash))
    # Возвращаем успешный результат
    return (1)
end

# Определяем функцию перевода токенов от одного адреса к другому с использованием разрешения
func token_transfer_from{state_ptr : State*}(from : felt, to : felt, value : Uint256) -> ():
    # Проверяем, что адреса валидные
    uint256_check(from)
    uint256_check(to)
    # Получаем адрес отправителя из стека вызовов
    let spender = fp - 3
    # Проверяем, что сумма перевода валидная
    uint256_check(value)
    # Читаем балансы владельца и получателя из словаря
    let from_balance = state_ptr.balances.read(from)
    let to_balance = state_ptr.balances.read(to)
    # Читаем разрешение из словаря
    let allowance = state_ptr.allowances.read(from, spender)
    # Вычитаем сумму перевода из баланса владельца
    let (new_from_balance, is_overflow) = uint256_add(from_balance, -value)
    # Проверяем, что у владельца достаточно токенов
    assert_not_zero(is_overflow == 0)
    # Вычит
