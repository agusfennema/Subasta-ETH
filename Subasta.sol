// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Subasta con incremento mínimo, reembolsos y extensión automática
/// @author Agustina
/// @notice Este contrato gestiona una subasta donde los participantes pueden:
///   1) Ofertar ETH (si su oferta supera en al menos 5% a la mayor actual),
///   2) Retirar parcialmente sus ofertas previas,
///   3) Ver ganadores y lista de oferentes,
///   4) Finalizar (devolver depósitos a no ganadores y cobrar 2% al ganador),
///   5) Extender la subasta si una oferta llega en los últimos 10 minutos.

contract Subasta {
    // ----------------------------------------
    // VARIABLES PRINCIPALES
    // ----------------------------------------

    /// @notice Dirección de quien creó la subasta (solo él puede finalizarla).
    address public owner;

    /// @notice Timestamp en que termina la subasta.
    uint public endTime;

    /// @notice Porcentaje mínimo que debe superar la nueva oferta (5%).
    uint public minIncrementPercent = 5;

    /// @notice Comisión que se cobra sobre la oferta ganadora (2%).
    uint public commissionPercent = 2;

    /// @notice Indica si la subasta ya fue finalizada.
    bool public ended;

    /// @notice Dirección del mejor oferente hasta el momento.
    address public highestBidder;

    /// @notice Monto total de la mejor oferta (cifra acumulada en bids[highestBidder]).
    uint public highestBid;

    /// @notice Monto total que cada participante ha ofrecido (incluye todas las transacciones).
    mapping(address => uint) public bids;

    /// @notice Historial de **cada** transacción de oferta para cada participante.
    ///   Sirve para poder reembolsar “las ofertas anteriores a la última válida”.
    mapping(address => uint[]) public bidHistory;

    /// @notice Lista con todas las direcciones que alguna vez hicieron una oferta.
    address[] public biddersList;

    // ----------------------------------------
    // EVENTOS
    // ----------------------------------------

    /// @notice Se emite cuando alguien hace una oferta válida (supera en 5% a la anterior).
    event NewOffer(address indexed bidder, uint amount);

    /// @notice Se emite cuando la subasta termina: indica quién ganó y con cuánto.
    event AuctionEnded(address winner, uint amount);

    /// @notice Se emite cuando un participante retira su importe por encima de la última oferta.
    event PartialRefund(address indexed bidder, uint amount);

    // ----------------------------------------
    // MODIFICADORES
    // ----------------------------------------

    /// @notice Solo el dueño (owner) puede ejecutar ciertas funciones.
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar");
        _;
    }

    /// @notice La subasta debe estar activa (antes de endTime y no finalizada).
    modifier auctionActive() {
        require(block.timestamp < endTime && !ended, "La subasta no esta activa");
        _;
    }

    /// @notice La subasta debe estar terminada (ya pasó endTime o el dueño la cerró).
    modifier auctionEnded() {
        require(block.timestamp >= endTime || ended, "La subasta sigue activa");
        _;
    }

    // ----------------------------------------
    // CONSTRUCTOR
    // ----------------------------------------

    /// @notice Inicializa la subasta con una duración en minutos.
    /// @param _durationMinutes Tiempo (en minutos) que durará la subasta desde el deploy.
    constructor(uint _durationMinutes) {
        owner = msg.sender;
        endTime = block.timestamp + (_durationMinutes * 1 minutes);
    }

    // ----------------------------------------
    // FUNCIONES PRINCIPALES
    // ----------------------------------------

    /// @notice Permite hacer una oferta en ETH si supera en al menos 5% la mejor oferta actual.
    /// @dev 
    ///   - Requiere msg.value > 0.
    ///   - Si no hay oferta previa (highestBid == 0), acepta cualquier valor > 0.
    ///   - Suma msg.value a bids[msg.sender] y actualiza bidHistory[msg.sender].
    ///   - Si la oferta llega en los últimos 10 min, extiende endTime 10 min más.
    function offer() external payable auctionActive {
        require(msg.value > 0, "Debes enviar ETH para ofertar");

        // Calculamos el mínimo requerido:  highestBid + (5% de highestBid)
        uint minRequiredBid = highestBid + (highestBid * minIncrementPercent / 100);

        // Si no hay oferta previa, permitimos cualquier valor > 0.
        if (highestBid == 0) {
            minRequiredBid = 0;
        }

        require(msg.value >= minRequiredBid, "Oferta debe ser al menos 5% mayor a la mejor oferta");

        // Si es la primera oferta de esta dirección, la agregamos a la lista.
        if (bids[msg.sender] == 0) {
            biddersList.push(msg.sender);
        }

        // Sumamos la nueva transacción a su monto total y guardamos en el historial.
        bids[msg.sender] += msg.value;
        bidHistory[msg.sender].push(msg.value);

        // Actualizamos quién es el mejor oferente y el monto de la mejor oferta.
        highestBidder = msg.sender;
        highestBid = bids[msg.sender];

        // Si faltan menos de 10 min para terminar, extendemos 10 min más.
        if (endTime - block.timestamp < 10 minutes) {
            endTime += 10 minutes;
        }

        emit NewOffer(msg.sender, bids[msg.sender]);
    }

    /// @notice Permite retirar **solo** las ofertas anteriores a la última válida (reembolso parcial).
    /// @dev 
    ///   - Solo mientras la subasta sigue activa (no al final).
    ///   - Suma todas las entradas en bidHistory[msg.sender] excepto la última.
    ///   - Resta ese monto de bids[msg.sender], marca esas entradas como 0 y transfiere el ETH.
    function partialRefund() external auctionActive {
        uint[] storage history = bidHistory[msg.sender];
        require(history.length > 1, "No hay oferta previa para reembolsar");

        // Sumamos todas las transacciones del historial menos la última.
        uint refundAmount = 0;
        for (uint i = 0; i < history.length - 1; i++) {
            refundAmount += history[i];
        }
        require(refundAmount > 0, "No hay importe para reembolsar");

        // Marcamos esas entradas previas como 0 (no borramos para ahorrar gas).
        for (uint i = 0; i < history.length - 1; i++) {
            history[i] = 0;
        }

        // Reducimos del total bids[msg.sender] lo que acabamos de devolver.
        bids[msg.sender] -= refundAmount;

        // Transferimos el reembolso
        payable(msg.sender).transfer(refundAmount);
        emit PartialRefund(msg.sender, refundAmount);
    }

    /// @notice Permite al dueño (owner) finalizar la subasta, devolver depósitos y cobrar comisión.
    /// @dev 
    ///   - Solo el owner puede llamarla, y solo si la subasta sigue activa y no ha terminado aún.
    ///   - Marca `ended = true`, luego:
    ///     1. Envía a cada no ganador el total de `bids[bidder]` (sin comisión).
    ///     2. Cobra al ganador su monto completo (`highestBid`): calcula 2% de comisión sobre esa cifra
    ///        y envía el resto al owner.
    function endAuction() external auctionActive onlyOwner {
        ended = true;

        // 1) Devolvemos a cada oferente que no ganó el total de su oferta
        for (uint i = 0; i < biddersList.length; i++) {
            address bidder = biddersList[i];
            if (bidder != highestBidder) {
                uint refund = bids[bidder];
                if (refund > 0) {
                    bids[bidder] = 0;
                    payable(bidder).transfer(refund);
                }
            }
        }

        // 2) Al ganador le cobramos la comisión del 2% sobre su highestBid
        if (highestBid > 0) {
            uint commission = (highestBid * commissionPercent) / 100;
            uint amountToOwner = highestBid - commission;
            // Marcamos su oferta en 0 para evitar reentradas
            bids[highestBidder] = 0;
            payable(owner).transfer(amountToOwner);
        }

        emit AuctionEnded(highestBidder, highestBid);
    }

    // ----------------------------------------
    // FUNCIONES DE LECTURA
    // ----------------------------------------

    /// @notice Devuelve (dirección del ganador, monto de la mejor oferta), pero solo luego de que finaliza la subasta.
    function getWinner() external view auctionEnded returns (address, uint) {
        return (highestBidder, highestBid);
    }

    /// @notice Devuelve dos arrays paralelos: [lista de direcciones], [sus montos totales ofertados].
    function getBidders() external view returns (address[] memory, uint[] memory) {
        uint len = biddersList.length;
        uint[] memory amounts = new uint[](len);
        for (uint i = 0; i < len; i++) {
            amounts[i] = bids[biddersList[i]];
        }
        return (biddersList, amounts);
    }
}
