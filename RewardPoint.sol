pragma solidity ^0.4.25;

/*
import "./BasicAuth.sol";
import "./RewardPointController.sol";
import "./RewardPointData.sol";
*/

// 定义基于角色的访问控制库
library LibRoles {
    // 存储角色
    struct Role {
        mapping (address => bool) bearer;
    }

    // 添加角色
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }
    // 移除角色
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }
    // 判断角色是否存在
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


// 发行者角色合约
contract IssuerRole {
    using LibRoles for LibRoles.Role;
    // 添加资产发行者事件
    event IssuerAdded(address indexed account);
    // 移除资产发行者事件
    event IssuerRemoved(address indexed account);
    // 设置LibRoles.Role类型别名 
    LibRoles.Role private _issuers;

    // 初始化资产发行者
    constructor () internal {
        _issuers.add(msg.sender);
    }

    // 仅允许资产发行者修饰器
    modifier onlyIssuer() {
        require(isIssuer(msg.sender), "IssuerRole: caller does not have the Issuer role");
        _;
    }
    // 判断是否是资产发行者
    function isIssuer(address account) public view returns (bool) {
        return _issuers.has(account);
    }
    // 添加资产发行者
    function addIssuer(address account) public {
        _issuers.add(account);
        emit IssuerAdded(account);
    }
    // 撤销资产发行者
    function renounceIssuer(address account) public onlyIssuer {
        _issuers.remove(account);
        emit IssuerRemoved(account);
    }
}



// 溢出检查库
library LibSafeMath {   
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
}














// 权限基合约
contract BasicAuth {
    // 所有者地址
    address public _owner;
    // 初始化所有者
    constructor() public {
        _owner = msg.sender;
    }
    // 仅允许所有者的修饰器
    modifier onlyOwner() { 
        require(auth(msg.sender), "Only owner!");
        _; 
    }
    // 设置所有者
    function setOwner(address owner)
        public
        onlyOwner
    {
        _owner = owner;
    }
    // 验证地址是否正确
    function auth(address src) public view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == _owner) {
            return true;
        } else {
            return false;
        }
    }
}



// 管理员合约
contract Admin is BasicAuth {
    // RewardPointData合约地址
    address public _dataAddress; 
    // RewardPointController合约地址
    address public _controllerAddress;

    //初始化
    constructor() public {
        // 创建RewardPointData合约
        RewardPointData data = new RewardPointData("Point of V1");
        _dataAddress = address(data);
        // 创建RewardPointController合约并传入RewardPointData合约地址
        RewardPointController controller = new RewardPointController(_dataAddress);
        _controllerAddress = address(controller);
        // 更新RewardPointController合约地址
        data.upgradeVersion(_controllerAddress);
        // 添加资产发行者
        data.addIssuer(msg.sender);
        // 添加RewardPointController合约地址
        data.addIssuer(_controllerAddress);
    }

    // 更新版本
    function upgradeVersion(address newVersion) public {
        RewardPointData data = RewardPointData(_dataAddress);
        //更新版本号
        data.upgradeVersion(newVersion);
    }
    
}

// RewardPoint积分存储合约
contract RewardPointData is BasicAuth, IssuerRole {
    // 存放积分余额
    mapping(address => uint256) private _balances;
    // 账户权限
    mapping(address => bool) private _accounts;
    // 积分总量
    uint256 public _totalAmount;
    // 描述信息
    string public _description;
    
    // 当前版本的地址
    address _latestVersion; 

    // 初始化描述信息
    constructor(string memory description) public {
        _description = description;
    }

    // 仅允许当前版本地址
    modifier onlyLatestVersion() {
       require(msg.sender == _latestVersion);
        _;
    }
    // 更新所有者
    function upgradeVersion(address newVersion) public {
        require(msg.sender == _owner);
        _latestVersion = newVersion;
    }
    
    // 设置余额积分
    function setBalance(address a, uint256 value) onlyLatestVersion public returns (bool) {
        _balances[a] = value;
        return true;
    }

    // 注册账户
    function setAccount(address a, bool b) onlyLatestVersion public returns (bool) {
        _accounts[a] = b;
        return true;
    }
    // 设置积分总量
    function setTotalAmount(uint256 amount) onlyLatestVersion public returns (bool) {
        _totalAmount = amount;
        return true;
    }

    // 返回账户积分余额
    function getAccountInfo(address account) public view returns (bool, uint256) {
        return (_accounts[account], _balances[account]);
    }

    // 判断账户是否注册
    function hasAccount(address account) public view returns(bool) {
         return _accounts[account];
    }

    // 返回账户积分余额
    function getBalance(address account) public view returns (uint256) {
        return _balances[account];
    }
   
}


interface IRewardPointController {
    
    function register() external;
    function unregister() external;
    function isRegistered(address addr) external view returns (bool);
    function isIssuer(address account) external view returns (bool);
    function issue(address account, uint256 value) external returns (bool);
    function balance(address addr) external view returns (uint256);

    function transfer(
        address toAddress, 
        uint256 value) 
        external returns(
        bool b, 
        uint256 balanceOfFrom, 
        uint256 balanceOfTo);

    function destroy(uint256 value) external returns (bool);
    function addIssuer(address account) external returns (bool);
    function renounceIssuer() external returns (bool);

}


contract RewardPointForUser {
    IRewardPointController rewardPointController;
    
    constructor(address reward) public {
        rewardPointController = IRewardPointController(reward);
    }

    // super {IRewardPointController.register}
    function register() public  {
        rewardPointController.register();
    }

    // super {IRewardPointController.unregister}
    function unregister() public  {
        rewardPointController.unregister();
    }

    // super {IRewardPointController.isRegistered}
    function isRegistered(address addr) public view returns (bool) {
        return rewardPointController.isRegistered(addr);
    }

    // super {IRewardPointController.isIssuer}
    function isIssuer(address addr) public view returns (bool) {
        return rewardPointController.isIssuer(addr);
    }

    // super {IRewardPointController.isIssuer}
    function issue(address account, uint256 value) public returns (bool) {    
        return rewardPointController.issue(account, value);
    }

    // super {IRewardPointController.balance}
    function balance(address addr) public view returns (uint256) {
        return rewardPointController.balance(addr);
    }

    // super {IRewardPointController.balance}
    function transfer(
        address toAddress, 
        uint256 value) 
        public returns(
        bool b, 
        uint256 balanceOfFrom, 
        uint256 balanceOfTo) 
    {
        return rewardPointController.transfer(toAddress, value);
    }

    // super {IRewardPointController.destroy}
    function destroy(uint256 value) public returns (bool) {
        return rewardPointController.destroy(value); 
    }

    // super {IRewardPointController.addIssuer}
    function addIssuer(address account) public returns (bool) {
        return rewardPointController.addIssuer(account);        
    }

    // super {IRewardPointController.renounceIssuer}
    function renounceIssuer() external returns (bool) {
        return rewardPointController.renounceIssuer();               
    }


}



// 定义RewardPointController业务操作合约
contract RewardPointController is BasicAuth, IRewardPointController {
    using LibSafeMath for uint256;
    // _rewardPointData合约地址，供调用
    RewardPointData _rewardPointData;

    // 定义事件
    event LogRegister(address account);
    event LogUnregister(address account);
    event LogSend( address indexed from, address indexed to, uint256 value);

    // 初始化rewardPointData数据合约地址
    constructor(address dataAddress) public {
        _rewardPointData = RewardPointData(dataAddress);
    }
    
    // 修饰器
    // 仅允许账户存在
    modifier accountExist(address addr) { 
        require(_rewardPointData.hasAccount(addr)==true && addr != address(0), "Only existed account!");
        _; 
    } 
    // 仅允许账户不存在
    modifier accountNotExist(address account) { 
        require(_rewardPointData.hasAccount(account)==false, "Account already existed!");
        _; 
    } 
    // 仅允许账户注销
    modifier canUnregister(address account) { 
        require(_rewardPointData.hasAccount(account)==true && _rewardPointData.getBalance(account) == 0 , "Cann't unregister!");
        _; 
    } 
    // 检查账户
    modifier checkAccount(address sender) { 
        require(msg.sender != sender && sender != address(0), "Can't transfer to illegal address!");
        _; 
    } 
    // 仅允许资产发行者
    modifier onlyIssuer() {
        require(_rewardPointData.isIssuer(msg.sender), "IssuerRole: caller does not have the Issuer role");
        _;
    }

    // 检查当前调用者
    modifier checkSender() {
        require(msg.sender != tx.origin, "The sender can't operator");
        _;
    }

    // 普通用户注册
    function register() checkSender accountNotExist(tx.origin) public {
        // 注册用户信息
        _rewardPointData.setAccount(tx.origin, true);
        // 初始化余额
        _rewardPointData.setBalance(tx.origin, 0);
        // 响应事件
        emit LogRegister(tx.origin);
    }

    // 普通用户账户注销
    function unregister() checkSender canUnregister(tx.origin)  public {
        // 注销用户信息
        _rewardPointData.setAccount(tx.origin, false);
        // 响应事件
        emit LogUnregister(tx.origin);
    }



    // 判断普通用户是否注册
    function isRegistered(address addr) public view returns (bool) {
        // 返回验证结果
        return _rewardPointData.hasAccount(addr);
    }

    // 查询普通用户积分
    function balance(address addr) public view returns (uint256) {
        // 返回查询结果
        return _rewardPointData.getBalance(addr);
    }

    // 往目标账户转积分
    function transfer(address toAddress, uint256 value) accountExist(tx.origin) accountExist(toAddress) checkSender
        public returns(bool b, uint256 balanceOfFrom, uint256 balanceOfTo) {
            // 获取发送方的积分余额
            uint256 balance1 = _rewardPointData.getBalance(tx.origin);
            // 减去发送方的积分
            balanceOfFrom = balance1.sub(value);
            // 更新发送方积分余额
            _rewardPointData.setBalance(tx.origin, balanceOfFrom);
            // 获取接收方的积分余额
            uint256 balance2 = _rewardPointData.getBalance(toAddress);
            // 增加接收方的积分
            balanceOfTo = balance2.add(value);
            // 更新接收方积分余额
            _rewardPointData.setBalance(toAddress, balanceOfTo);
            // 响应事件
            emit LogSend(tx.origin, toAddress, value);
            // 返回执行结果
            b = true;
    }

    // 销毁自己账户中指定数量的积分
    function destroy(uint256 value) accountExist(tx.origin) checkSender public returns (bool) {
        // 获取总积分
        uint256 totalAmount = _rewardPointData._totalAmount();
        // 从总积分中减去销毁的积分数量
        totalAmount = totalAmount.sub(value);
        // 更新总积分
        _rewardPointData.setTotalAmount(totalAmount);
        // 获取账户积分余额
        uint256 balance1 = _rewardPointData.getBalance(tx.origin);
        // 减去账户的积分
        balance1 = balance1.sub(value);
        // 更新余额
        _rewardPointData.setBalance(tx.origin, balance1);
        // 响应事件
        emit LogSend(tx.origin, address(0), value);
        // 返回执行结果
        return true;
    }

    // 发行积分
    function issue(address account, uint256 value) public accountExist(account) returns (bool) {
        // 获取总积分
        uint256 totalAmount = _rewardPointData._totalAmount();
        // 从总积分中增加积分数量   
        totalAmount = totalAmount.add(value);
        // 更新总积分       
        _rewardPointData.setTotalAmount(totalAmount);
        // 获取账户积分余额
        uint256 balance1 = _rewardPointData.getBalance(account);
        // 增加账户的积分
        balance1 = balance1.add(value);
        // 更新余额
        _rewardPointData.setBalance(account, balance1);
        // 响应事件
        emit LogSend( address(0), account, value);
        // 返回执行结果
        return true;
    }

    // 判断是否是资产发行者
    function isIssuer(address account) public view returns (bool) {
        return _rewardPointData.isIssuer(account);
    }
    // 添加资产发行者
    function addIssuer(address account) public  accountExist(account) returns (bool) {
        _rewardPointData.addIssuer(account);
        return true;
    }
    // 撤销资产发行者
    function renounceIssuer() public accountExist(tx.origin) checkSender returns (bool) {
        _rewardPointData.renounceIssuer(tx.origin);
        return true;
    }
}
