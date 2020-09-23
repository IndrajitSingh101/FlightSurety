pragma solidity ^0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    address[] private registeredAirlines;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    struct Flight {
        string flight;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    struct Airline {
        address airline;
        string airlineName;
        bool isRegistered;
        bool fundingSubmitted;
        uint registrationVotes;
    }

    struct Insurance {
        address insuree;
        uint256 insuredAmount;
    }
    mapping(bytes32 => Flight) private flights;
    mapping(address=>bool) private authorizedCallers;
    mapping(address=>Airline) private airlines;
    mapping(bytes32=>bool) airlineRegistrationVotes;
    mapping(bytes32=>Insurance[]) private policies;
    mapping(address=>uint256) private credits;

    event AddedAirline(address airline);
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public
    {
        contractOwner = msg.sender;
        authorizedCallers[msg.sender]=true;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller(){
        require(authorizedCallers[msg.sender]==true,"User is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            requireAuthorizedCaller
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeCaller(address caller)external requireContractOwner{
       authorizedCallers[caller]=true; 
    }

    function deauthorizeCaller(address caller)external requireContractOwner{
       authorizedCallers[caller]=false;  
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airline,
                                string calldata airlineName
                            )
                            external
                            requireAuthorizedCaller
                            requireIsOperational
    {
        airlines[airline]=Airline({
            airline: airline,
            airlineName: airlineName,
            isRegistered: false,
            fundingSubmitted: false,
            registrationVotes: 0
        });
        emit AddedAirline(airline);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
 function hasAirlineBeenAdded(address airline)
 external 
 view 
 requireAuthorizedCaller
requireIsOperational
returns(bool)
{
return airlines[airline].airline==airline;
}

function addToRegisteredAirlines(
    address airline
) 
external
requireIsOperational
requireAuthorizedCaller
{
airlines[airline].isRegistered=true;
registeredAirlines.push(airline);
}

function hasAirlineBeenRegistered(address airline)
external
view
requireAuthorizedCaller
requireIsOperational
returns(bool)
{
    return airlines[airline].isRegistered;
}

function getRegisteredAirlines()
external
view
requireAuthorizedCaller
requireIsOperational
returns(address[] memory){
    return registeredAirlines; 
}

function hasAirlineVotedFor(
address airlineVoterID,
address airlineVoteeID
) external
view 
requireAuthorizedCaller
requireIsOperational
returns(bool)
{
    bytes32 voteHash=keccak256(abi.encodePacked(airlineVoterID,airlineVoteeID));
    return airlineRegistrationVotes[voteHash]==true;
}

function voteForAirline(
    address airlineVoterID,
    address airlineVoteeID
)external
requireAuthorizedCaller
requireIsOperational
returns (uint) 
{
bytes32 voteHash = keccak256(
            abi.encodePacked(airlineVoterID, airlineVoteeID));
        airlineRegistrationVotes[voteHash] = true;
        airlines[airlineVoteeID].registrationVotes += 1;

        return airlines[airlineVoteeID].registrationVotes;
}

function setFundingSubmitted(address airline)
external
requireAuthorizedCaller
requireIsOperational
{
    airlines[airline].fundingSubmitted=true;

}

function hasFundingBeenSubmitted(
    address airline
)
external
view
requireAuthorizedCaller
requireIsOperational
returns(bool)
{
    return airlines[airline].fundingSubmitted==true;
}

function addToRegisteredFlights(
    address airline,
    string calldata flight,
    uint256 timestamp
)
external
requireAuthorizedCaller
requireIsOperational
{
    flights[getFlightKey(airline,flight,timestamp)]=Flight(
        {
            flight: flight,
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline
        }
    );
}

function addToInsurancePolicy(
    address airline,
    string  calldata flight,
    address insuree,
    uint256 amountToInsureFor
)
external
requireAuthorizedCaller
requireIsOperational{
    policies[keccak256(abi.encodePacked(airline,flight))].push(
        Insurance(
            {
                insuree: insuree,
                insuredAmount: amountToInsureFor
            }
        )
    );
}

function creditInsurees(
    address airline,
    string calldata flight,
    uint256 creditMultiplier
)
external
requireAuthorizedCaller
requireIsOperational
{
    bytes32 policyKey=keccak256(abi.encodePacked(airline,flight));
    Insurance[] memory policiesToCredit=policies[policyKey];
    uint256 currentCredits;
    for(uint i=0;i<policiesToCredit.length;i++){
        currentCredits=credits[policiesToCredit[i].insuree];
        uint256 creditsPayout=(
            policiesToCredit[i].insuredAmount.mul(creditMultiplier).div(10));
        credits[policiesToCredit[i].insuree]=currentCredits.add(creditsPayout);

    }

    delete policies[policyKey];
}

function withdrawCreditsForInsuree(
    address insuree
)
external
requireAuthorizedCaller
requireIsOperational
payable
{
uint256 creditsAvailable=credits[insuree];
require(creditsAvailable>0,"Requires credits are available");
credits[insuree]=0;
address payable  dataAddr= address(uint160(insuree));
dataAddr.transfer(creditsAvailable);
}
   

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

   fallback() external payable{

   }
   receive() external payable{
       
   }
  
}

