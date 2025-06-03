# Subasta-ETH
# 🛍️ Contrato de Subasta en Solidity

Este contrato inteligente implementa una **subasta dinámica con mejoras** que permiten transparencia, competencia justa y reembolsos parciales. Fue desarrollado en Solidity y pensado para ejecutarse en la red Ethereum.

## ✨ Características principales

- ✅ Las ofertas deben **superar al menos un 5%** la oferta más alta.
- ⏳ Si una oferta llega en los **últimos 10 minutos**, la subasta se extiende automáticamente.
- 💸 El **ganador paga una comisión del 2%**, el resto va al organizador.
- ♻️ Los participantes pueden **retirar sus ofertas previas** si no son la actual ganadora.
- 🧾 Se guarda el historial de todas las ofertas y se puede consultar ganadores y oferentes.

---

## 🧠 ¿Cómo funciona?

### 1. Inicio de la subasta
Al desplegar el contrato, el creador (owner) define la duración de la subasta en minutos. Desde ese momento, comienza a correr el reloj.

### 2. Realizar una oferta
Cualquier persona puede hacer una oferta (en ETH) siempre que:
- Sea **mayor en al menos 5%** a la actual mejor oferta.
- En caso de ser la **primera oferta**, se acepta cualquier monto positivo.

Si la oferta llega cuando faltan menos de 10 minutos para el cierre, el sistema **extiende automáticamente la subasta 10 minutos más**, favoreciendo la competencia.

### 3. Retiro parcial de ofertas
Los participantes pueden **retirar el dinero de sus ofertas anteriores**, siempre que no sean la última oferta válida.  
Esto permite recuperar fondos sin abandonar la subasta.

### 4. Finalización de la subasta
Solo el **dueño del contrato** puede finalizarla. Al hacerlo:
- Se reembolsa el 100% de lo ofertado a todos los **no ganadores**.
- El **ganador** paga una **comisión del 2%**, y el resto del monto ofertado se transfiere al owner.

### 5. Consultas disponibles
- Ver al **ganador y monto final** (después de que termina la subasta).
- Obtener la **lista de oferentes** y cuánto ofreció cada uno.

---

## 📌 Reglas técnicas

- Solo se permite finalizar la subasta **una vez**.
- La subasta se considera activa si:
  - El tiempo actual es menor al tiempo de finalización.
  - Y no fue marcada como finalizada manualmente.
- La oferta ganadora se determina por el **monto total acumulado por dirección** (no solo por la última transacción).
- El historial de transacciones se guarda para permitir **reembolsos parciales**.

---

## 👩‍💻 Autoría

**Desarrollado por:** Agustina  
**Lenguaje:** Solidity 0.8.19  
**Licencia:** MIT

---

