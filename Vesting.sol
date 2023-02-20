// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // cliff period in seconds
        uint256 cliff;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // whether or not the vesting is revocable
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
    }

    // address of the ERC20 token
    IERC20 public immutable _token;
    address[] public vestingBeneficiaries;
    uint256 public vestingSchedulesTotalAmount;
    mapping(address => VestingSchedule) public vestingSchedules;
    event Released(address beneficiary, uint256 amount);

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        uint256 _amount
    ) public {
        require(
            this.getWithdrawableAmount() >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(
            _slicePeriodSeconds >= 1,
            "TokenVesting: slicePeriodSeconds must be >= 1"
        );
        // bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(
        //     _beneficiary
        // );
        uint256 cliff = _start.add(_cliff);
        vestingSchedules[_beneficiary] = VestingSchedule(
            _beneficiary,
            _start,
            cliff,
            _duration,
            _slicePeriodSeconds,
            _amount,
            0
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingBeneficiaries.push(_beneficiary);
        // uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        // holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)).sub(vestingSchedulesTotalAmount);
    }

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     */
    function getToken() external view returns (address) {
        return address(_token);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(address _beneficiary)
        public
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[_beneficiary];
    }

    /**
     * @notice Release vested amount of tokens.
     * @param _beneficiary the amount to release
     */
    function release(address _beneficiary) public nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[_beneficiary];
        // require(
        //     msg.sender == vestingSchedule.beneficiary,
        //     "TokenVesting: only beneficiary and owner can release vested tokens"
        // );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        // require(
        //     vestedAmount >= _amount,
        //     "TokenVesting: cannot release tokens, not enough vested tokens"
        // );
        vestingSchedule.released = vestingSchedule.released.add(vestedAmount);
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(vestedAmount);
        _token.safeTransfer(beneficiaryPayable, vestedAmount);
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.cliff)) {
            return 0;
        } else if (
            currentTime >= vestingSchedule.start.add(vestingSchedule.duration)
        ) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule
                .amountTotal
                .mul(vestedSeconds)
                .div(vestingSchedule.duration);
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
            return vestedAmount;
        }
    }

    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }
}
