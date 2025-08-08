# PB Vehicle Manager (ESX + ox_lib)
Správce vozidel pro ESX s krásným **ox_lib** UI:
- **Přidávání** vozidel do **osobní** i **frakční (society)** garáže  
- **Mazání** vozidel z osobní/society garáže  
- **Změna SPZ** s validací a velkým **blacklistem** výrazů  
- **Discord logy** (bohaté embed karty, **oddělené webhooky** pro přidávání a mazání)  
- **Zachování inventáře** ve vozidle (glovebox & trunk) při změně SPZ – automaticky přejmenuje stash názvy

> Testováno na ESX (imports), `ox_lib`, `oxmysql`, `ox_inventory` (stash DB).

---

## ✨ Funkce

- UI přes **ox_lib context menu + input dialogy**
- **Přidat** do:
  - **Osobní garáže** konkrétnímu hráči (podle server ID)
  - **Frakční garáže** (zadáním `society`/`job`)
- **Smazat** z:
  - **Osobní garáže** hráče (výběr z jeho vozidel)
  - **Frakční garáže** (výběr z vozidel dané society)
- **Změnit SPZ**:
  - Po výběru vozidla zadáš novou SPZ (regex + délka + **blacklist**)
  - Přenastaví se `plate` ve sloupci i v JSON vlastnostech
  - **Zachová inventář** (přejmenuje `glovebox:<plate>` a `trunk:<plate>` na novou SPZ)
- **Oprávnění**: jen ESX group definované v `Config.AllowedGroups`
- **Logování**:
  - **Oddělený webhook** pro přidávání a pro mazání
  - Embed obsahuje **admina** (jméno, server ID, Discord ID, Steam hex, license), **cílového hráče** nebo **society**, a detaily **vozidla** (SPZ, model, typ, label)

---

## 📦 Požadavky

- **es_extended** (nový import `@es_extended/imports.lua`)
- **ox_lib**
- **oxmysql**
- **ox_inventory** (volitelně – pouze pokud chceš zachovat inventář při změně SPZ)

---

## 🛠️ Instalace

1. Nakopíruj složku resource, např. `pb_vehicle_manager/`.
2. Do `server.cfg` přidej v pořadí:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure es_extended
   ensure pb_vehicle_manager
