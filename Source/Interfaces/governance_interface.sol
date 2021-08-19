pragma solidity ^0.6.6;

interface governance_interface {
    function raffle() external view returns (address);
    function randomness() external view returns (address);
}
