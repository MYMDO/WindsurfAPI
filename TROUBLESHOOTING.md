# 🆘 Вирішення проблем (Troubleshooting)

Українською мовою. Якщо ви знайшли нову проблему — будь ласка, [відкрийте Issue](https://github.com/MYMDO/WindsurfAPI/issues).

---

## 1️⃣ Усі моделі повертають 403

**Симптом:**
```json
{"error":"模型 claude-sonnet-4.6 不在允許清單中"}
```
або
```json
{"error":"Model claude-sonnet-4.6 is not in the allowed list"}
```

**Причина:** Файл `.docker-data/data/model-access.json` у режимі `allowlist`.

**Рішення:**
```bash
curl -s -X PUT http://localhost:3003/dashboard/api/model-access \
  -H "X-Dashboard-Password: ваш_пароль" \
  -H "Content-Type: application/json" \
  -d '{"mode":"all","list":[]}'
```

**Профілактика:**
```bash
chmod 444 ./.docker-data/data/model-access.json
```
Це робить файл read-only — навіть Dashboard не зможе його змінити випадково.

---

## 2️⃣ 401 Unauthorized при підключенні

**Симптом:**
```json
{"error":"Unauthorized"}
```

**Причина:** Сервер слухає на `0.0.0.0` (а не `127.0.0.1`), і активовано fail-closed режим. Усі запити вимагають `Authorization: Bearer <API_KEY>`.

**Рішення:**
1. Переконайтеся, що у `.env` встановлено `API_KEY=something`
2. Додавайте заголовок до кожного запиту:
   ```
   Authorization: Bearer local-dev-key
   ```

---

## 3️⃣ "Model not entitled" / модель недоступна

**Симптом:**
```json
{"error":"model_not_entitled"}
```

**Причина:** Ваш акаунт Windsurf має Free-тариф і не має доступу до запитаної моделі.

**Рішення:**
1. Перевірте тариф акаунта в Dashboard → Accounts
2. Безкоштовні акаунти мають доступ лише до: `gemini-2.5-flash`, `glm-4.7/5/5.1`, `kimi-k2/k2.5/k2-6`, `qwen-3`
3. Для Claude/GPT/Opus потрібен Pro-тариф

**Probe-команда (оновити кеш можливостей):**
```bash
curl -X POST http://localhost:3003/dashboard/api/accounts/ID/probe \
  -H "X-Dashboard-Password: ваш_пароль"
```
ID акаунта можна знайти в Dashboard або через:
```bash
curl http://localhost:3003/dashboard/api/accounts \
  -H "X-Dashboard-Password: ваш_пароль"
```

---

## 4️⃣ Схоже, що модель не підтримує інструменти

**Симптом:** Модель відповідає текстом, але не виконує читання/запис файлів.

**Причина:** Безкоштовні моделі (gemini-2.5-flash, glm, kimi) не підтримують інструменти.

**Рішення:** Використовуйте Claude-моделі (claude-4.5-haiku, claude-sonnet-4.6). Вони потребують Pro-тарифу.

**OpenCode / Claude Code користувачам:** Free-акаунт НЕ підходить — OpenCode надсилає 12 інструментів, які free-tier моделі відхиляють. Тільки Pro.

---

## 5️⃣ Таймаут / зависання при довгих запитах

**Симптом:** Запит висить > 60 секунд, потім помилка.

**Причина:** Cold start Language Server + довгий вхідний текст.

**Рішення:** Оновіть до останньої версії — починаючи з v2.0.96, cold stall detection адаптивний до довжини тексту (макс 90с).

---

## 6️⃣ Локальний імпорт не працює

**Симптом:** Кнопка "Import from local Windsurf" недоступна або повертає помилку.

**Причина:** Локальний імпорт працює ТІЛЬКИ з `127.0.0.1`. Відкрийте Dashboard через `http://127.0.0.1:3003/dashboard`, а не через публічний домен.

---

## 7️⃣ Помилка логіну "Invalid email or password"

**Причина:** Ви зареєструвалися у Windsurf через Google/GitHub. Такий акаунт не має пароля.

**Рішення:** Використовуйте кнопки "Google Login" або "GitHub Login" у Dashboard замість форми email/пароль. Або перейдіть на [windsurf.com/show-auth-token](https://windsurf.com/show-auth-token), скопіюйте токен і додайте через поле Token.

---

## 8️⃣ Оновлення одним кліком не працює

**Симптом:** Кнопка "Check Update" показує "Not a git repository".

**Причина:** Ви розгорнули сервіс через SFTP/zip, а не через git clone.

**Рішення:**
- **Docker:** `docker compose pull && docker compose up -d`
- **Node.js:** Вручну завантажте нові файли та перезапустіть: `pm2 restart windsurf-api`

---

## 9️⃣ Cursor блокує моделі Claude

**Симптом:** У Cursor модель з назвою `claude-sonnet-4.6` не працює.

**Причина:** Cursor має клієнтський білий список, який блокує назви з `claude`.

**Рішення:** Використовуйте псевдоніми:

| Введіть у Cursor | Фактична модель |
|---|---|
| `opus-4.6` | claude-opus-4.6 |
| `sonnet-4.6` | claude-sonnet-4.6 |
| `opus-4.7` | claude-opus-4-7-medium |
| `ws-opus` | claude-opus-4.6 |
| `ws-sonnet` | claude-sonnet-4.6 |

GPT / Gemini / DeepSeek моделі проходять без фільтрації.

---

## 🔟 Після 150+ запитів моделі перестають працювати

**Причина:** Певні моделі (claude-opus-4-7-max, gpt-5.5-xhigh) мають тижневу квоту ~5 викликів на акаунт. Якщо у вас 31 акаунт × 5 = ~155 викликів, і квота вичерпана.

**Рішення:** Перейдіть на `claude-sonnet-4.6` або `claude-4.5-haiku` — вони мають денні квоти, які значно більші.

**Перевірка:**
```bash
docker logs windsurfapi-windsurf-api-1 | grep rate_limit
```

---

## Де отримати допомогу

- **Українська документація:** `README.ua.md`
- **Підводні камені (цей файл):** `TROUBLESHOOTING.md`
- **OpenCode інтеграція:** приклад у `opencode.json`
- **Issue tracker:** https://github.com/MYMDO/WindsurfAPI/issues
