
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//                   Version 2, December 2004
// 
//CryptoSteam @2021,All rights reserved
//
//Everyone is permitted to copy and distribute verbatim or modified
//copies of this license document, and changing it is allowed as long
//as the name is changed.
// 
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
//
// You just DO WHAT THE FUCK YOU WANT TO.

pragma solidity ^0.8.0;

library MathEx
{
    function rand(uint256 number) public view returns(uint256) {
        if (number == 0) {
            return 0;
        }
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return random % number;
    }

    function rand2(uint256 number, uint256 seed) public view returns(uint256) {
        if (number == 0) {
            return 0;
        }
        uint256 random = uint256(keccak256(abi.encodePacked(seed, block.difficulty, block.timestamp)));
        return random % number;
    }

    function rand3() public view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function rand3ex(uint256 seed) public view returns(uint256) {
        if (seed==0){
            return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        }else{
            return uint256(keccak256(abi.encodePacked(seed,block.difficulty, block.timestamp)));
        }
    }


    function scopeRand(uint256 beginNumber,uint256 endNumber) public view returns(uint256){
        return rand(endNumber-beginNumber+1)+beginNumber;
    }

    function scopeRandR(uint256 beginNumber,uint256 endNumber, uint256 rnd) public pure returns(uint256){
        if (endNumber <= beginNumber) {
            return beginNumber;
        }
        return (rnd % (endNumber-beginNumber+1))+beginNumber;
    }

    function probabilisticRandom(uint256 [] memory probabilities) view public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<probabilities.length;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rand(totalRarityProbability);
        for (uint256 i=0;i<probabilities.length;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom6(uint256 [6] memory probabilities) view public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<6;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rand(totalRarityProbability);
        for (uint256 i=0;i<6;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom6R(uint256 [6] memory probabilities, uint256 rnd) pure public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<6;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rnd % totalRarityProbability;
        for (uint256 i=0;i<6;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom4(uint256 [4] memory probabilities) view public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<4;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rand(totalRarityProbability);
        for (uint256 i=0;i<4;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom4R(uint256 [4] memory probabilities, uint256 rnd) pure public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<4;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rnd % totalRarityProbability;
        for (uint256 i=0;i<4;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom5(uint256 [5] memory probabilities) view  public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<5;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rand(totalRarityProbability);
        for (uint256 i=0;i<5;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

    function probabilisticRandom5R(uint256 [5] memory probabilities, uint256 rnd) pure public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<5;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=rnd % totalRarityProbability;
        for (uint256 i=0;i<5;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }

}
