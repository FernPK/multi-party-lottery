// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Lottery {

    struct Player {
        uint commit;
        bool revealed;
        bool beCandidate;
    }

    struct Candidate {
        uint randomNum;
        address addr;
    }

    mapping (address => Player) public player;
    mapping (uint => Candidate) public candidate;
    
    uint256 public startTime = 0;
    uint256 public T1;
    uint256 public T2;
    uint256 public T3;
    
    uint256 public numPlayer = 0;
    uint256 public maxNumPlayer;
    uint256 public numCandidate = 0;
    uint256 public totalValue = 0;
    uint256 public xorRandomNum = 0;

    uint256 public winner;
    address public owner;

    address[] public allPlayer;

    modifier isOwner() {
        require(msg.sender == owner, "Must be owner of contract");
        _;
    }

    constructor(uint _T1, uint _T2, uint _T3, uint _maxNumPlayer) {
        T1 = _T1; // sec
        T2 = _T2; // sec
        T3 = _T3; // sec
        maxNumPlayer = _maxNumPlayer;
        owner = msg.sender;
        winner = _maxNumPlayer; // no winner
    }

    function joinAndCommit(uint _commitHash) external payable {
        require(numPlayer < maxNumPlayer, "Party is full");
        require(startTime == 0 || block.timestamp <= startTime + T1, "Not in participation period");
        require(player[msg.sender].commit == 0, "You are now a player");
        require(msg.value == 0.001 ether, "Please send 0.001 ether");
        numPlayer++;
        totalValue += msg.value;
        player[msg.sender].commit = _commitHash;
        player[msg.sender].revealed = false;
        player[msg.sender].beCandidate = false;
        allPlayer.push(msg.sender);
        if (numPlayer == 1) { // First player has joined
            startTime = block.timestamp;
        }
    }

    function reveal(uint _commit, uint _salt) external {
        require(startTime != 0 && block.timestamp > startTime + T1 && block.timestamp <= startTime + T1 + T2, "Not in number revealing period");
        require(player[msg.sender].commit != 0, "You are not a player");
        require(_commit >= 0 && _commit <= 999, "Random number must in range 0-999. You didn't follow the rule");
        require(getHash( _commit, _salt) == player[msg.sender].commit, "Revealed hash does not match commit");
        require(player[msg.sender].revealed == false, "Already revealed");
        player[msg.sender].revealed = true;
        candidate[numCandidate].randomNum = _commit;
        candidate[numCandidate].addr = msg.sender;
        numCandidate++;
        player[msg.sender].beCandidate = true;
    }

    function drawWinner() external isOwner {
        require(startTime != 0 && block.timestamp > startTime + T1 + T2 && block.timestamp <= startTime + T1 + T2 + T3, "Not in winner drawing period");
        require(totalValue > 0, "drawWinner can be called only once");
        if (numCandidate > 0) {
            for (uint i = 0; i < numCandidate; i++) {
                xorRandomNum = xorRandomNum ^ candidate[i].randomNum;
            }
            winner = uint(keccak256(abi.encodePacked(xorRandomNum)))%numCandidate;
            uint256 prize = 0.001 ether * numCandidate * 98 / 100;
            payable(candidate[winner].addr).transfer(prize);
            totalValue -= prize;
            payable(owner).transfer(totalValue);
        }
        else if (numCandidate == 0) {
            payable(owner).transfer(totalValue);
        }
        totalValue = 0;
    }

    function refund() external {
        require(totalValue > 0, "Cannot be refunded");
        require(startTime != 0 && block.timestamp > startTime + T1 + T2 + T3, "Not in refund period");
        require(player[msg.sender].commit != 0, "You have received your refund");
        totalValue -= 0.001 ether;
        player[msg.sender].commit = 0;
        payable(msg.sender).transfer(0.001 ether);
    }

    function resetState() external isOwner {
        require(totalValue == 0, "Previous round is not finished yet");
        for (uint i = 0; i < numCandidate; i++){
            delete candidate[i];
        }
        for (uint i = 0; i < numPlayer; i++){
            delete player[allPlayer[i]];
        }
        startTime = 0;
        numPlayer = 0;
        numCandidate = 0;
        xorRandomNum = 0;
        winner = maxNumPlayer;
        delete allPlayer;
    }

    function getHash(uint _commit, uint _salt) public view returns(uint){
        return uint(keccak256(abi.encodePacked(msg.sender, _commit, _salt)));
    }
}
