// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "sismo-connect-solidity/SismoConnectLib.sol";

contract MasterContract is SismoConnect {
    struct Transaction {
        address sender;
        address receiver;
        uint256 amount;
    }

    mapping(uint256 => uint256) private balances;

    event Deposit(address indexed depositor, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event ResponseVerified(SismoConnectVerifiedResult result);
    event Balance(uint256 balance);

    // constructor function
    constructor(
        bytes16 _appId,
        bool _isImpersonationMode
    )
        SismoConnect(
            buildConfig({
                appId: _appId,
                isImpersonationMode: _isImpersonationMode
            })
        )
    {}

    // deposit function
    function deposit() external payable {
        require(msg.value > 0, "Amount should be greater than 0");
        balances[uint256(uint160(msg.sender))] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function privateTransfer(
        uint256 _amount,
        address _to,
        bytes memory _response
    ) external {
        require(
            balances[uint256(uint160(msg.sender))] >= _amount,
            "Insufficient balance"
        );
        SismoConnectVerifiedResult memory result = verifySismoConnectResponse(
            _response
        );
        uint256[] memory evmAccountIds = SismoConnectHelper.getUserIds(
            result,
            AuthType.EVM_ACCOUNT
        );
        balances[evmAccountIds[0]] -= _amount;
        balances[uint256(uint160(_to))] += _amount;
        emit Transfer(msg.sender, _to, _amount);
    }

    // withdraw function
    function withdraw(uint256 _amount, bytes memory _response) external {
        require(_amount > 0, "Amount should be greater than 0");
        SismoConnectVerifiedResult memory result = verifySismoConnectResponse(
            _response
        );
        uint256[] memory evmAccountIds = SismoConnectHelper.getUserIds(
            result,
            AuthType.EVM_ACCOUNT
        );

        balances[evmAccountIds[0]] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }

    // get balance function
    function getBalance(bytes memory _response) external {
        SismoConnectVerifiedResult memory result = verifySismoConnectResponse(
            _response
        );
        uint256[] memory evmAccountIds = SismoConnectHelper.getUserIds(
            result,
            AuthType.EVM_ACCOUNT
        );
        require(evmAccountIds.length > 0, "No EVM account found");
        emit Balance(balances[evmAccountIds[0]]);
    }

    // verify response function
    function verifySismoConnectResponse(
        bytes memory response
    ) private view returns (SismoConnectVerifiedResult memory) {
        AuthRequest[] memory auths = new AuthRequest[](1);
        auths[0] = buildAuth({authType: AuthType.EVM_ACCOUNT});

        SismoConnectVerifiedResult memory result = verify({
            responseBytes: response,
            auths: auths
        });
        return result;
    }
}
