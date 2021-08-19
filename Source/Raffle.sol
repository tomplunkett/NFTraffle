pragma solidity ^0.6.6;
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import {randomness_interface} from "./interfaces/randomness_interface.sol";
import {governance_interface} from "./interfaces/governance_interface.sol";

contract Raffle is ChainlinkClient {
    enum RAFFLE_STATE { OPEN, CLOSED, CALCULATING_WINNER }
    RAFFLE_STATE public raffle_state;
    uint256 public raffleId;
    address payable[] public players;
    governance_interface public governance;
    // .01 ETH
    uint256 public MINIMUM = 1000000000000000;
    // 0.1 LINK
    uint256 public ORACLE_PAYMENT = 100000000000000000;
    // Alarm stuff
    address CHAINLINK_ALARM_ORACLE = 0xc99B3D447826532722E41bc36e644ba3479E4365;
    bytes32 CHAINLINK_ALARM_JOB_ID = "2ebb1c1a4b1e4229adac24ee0b5f784f";
    
    constructor(address _governance) public
    {
        setPublicChainlinkToken();
        raffleId = 1;
        raffle_state = RAFFLE_STATE.CLOSED;
        governance = governance_interface(_governance);
    }

    function enter() public payable {
        assert(msg.value == MINIMUM);
        assert(raffle_state == RAFFLE_STATE.OPEN);
        players.push(msg.sender);
    } 
    
  function start_new_raffle(uint256 duration) public {
    require(raffle_state == RAFFLE_STATE.CLOSED, "can't start a new raffle yet");
    raffle_state = RAFFLE_STATE.OPEN;
    Chainlink.Request memory req = buildChainlinkRequest(CHAINLINK_ALARM_JOB_ID, address(this), this.fulfill_alarm.selector);
    req.addUint("until", now + duration);
    sendChainlinkRequestTo(CHAINLINK_ALARM_ORACLE, req, ORACLE_PAYMENT);
  }
  
  function fulfill_alarm(bytes32 _requestId)
    public
    recordChainlinkFulfillment(_requestId)
      {
        require(raffle_state == RAFFLE_STATE.OPEN, "The raffle hasn't even started!");
        // add a require here so that only the oracle contract can
        // call the fulfill alarm method
        raffle_state = RAFFLE_STATE.CALCULATING_WINNER;
        raffleId = raffleId + 1;
        pickWinner();
    }


    function pickWinner() private {
        require(raffle_state == RAFFLE_STATE.CALCULATING_WINNER, "You aren't at that stage yet!");
        randomness_interface(governance.randomness()).getRandom(raffleId, raffleId);
        //this kicks off the request and returns through fulfill_random
    }
    
    function fulfill_random(uint256 randomness) external {
        require(raffle_state == RAFFLE_STATE.CALCULATING_WINNER, "You aren't at that stage yet!");
        require(randomness > 0, "random-not-found");
        // assert(msg.sender == governance.randomness());
        uint256 index = randomness % players.length;
        players[index].transfer(address(this).balance);
        players = new address payable[](0);
        raffle_state = RAFFLE_STATE.CLOSED;
        // You could have this run forever
        // start_new_raffle();
        // or with a cron job from a chainlink node would allow you to 
        // keep calling "start_new_raffle" as well
    }

    function get_players() public view returns (address payable[] memory) {
        return players;
    }
    
    function get_pot() public view returns(uint256){
        return address(this).balance;
    }
}


