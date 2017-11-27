import increaseTime, { duration } from 'zeppelin-solidity/test/helpers/increaseTime';
import moment from 'moment';


var Token = artifacts.require("./TripleAlphaTokenPreICO.sol");
var Crowdsale = artifacts.require("./TripleAlphaCrowdsalePreICO.sol");


contract('Crowdsale', (accounts) => {
    let owner, token, sale;
    let startTime1, startTime2, endTime1, endTime2;
    let client1, client2, client3, client4;
    let wallet;

    before(async () => {
        owner = web3.eth.accounts[0];
        client1 = web3.eth.accounts[1];
        client2 = web3.eth.accounts[2];
        client3 = web3.eth.accounts[3];
        client4 = web3.eth.accounts[4];

        wallet = web3.eth.accounts[5];
    });

    let balanceEqualTo = async (client, should_balance) => {
        let balance;

        balance = await token.balanceOf(client, {from: client});
        assert.equal((balance.toNumber()/1e18).toFixed(4), (should_balance/1e18).toFixed(4), `Token balance should be equal to ${should_balance}`);
    };

    let shouldHaveException = async (fn, error_msg) => {
        let has_error = false;

        try {
            await fn();
        } catch(err) {
            has_error = true;
        } finally {
            assert.equal(has_error, true, error_msg);
        }        

    }

    let check_constant = async (key, value, text) => {
        assert.equal(((await sale[key]()).toNumber()/1e18).toFixed(2), value, text)
    };

    let check_calcAmount = async (ethers, at, should_tokens, should_odd_ethers) => {
        should_tokens = ((should_tokens || 0)/1e18).toFixed(2);
        should_odd_ethers = ((should_odd_ethers || 0)/1e18).toFixed(2);

        let text = `Check ${ethers/1e18} ETH → ${should_tokens} TRIA`;
        let textOdd = `Check ${ethers/1e18} ETH → ODD ${should_odd_ethers} ETH`;

        let result = await sale.calcAmountAt(ethers, at);
        let tokens = (result[0].toNumber()/1e18).toFixed(2);
        let odd_ethers = (result[1].toNumber()/1e18).toFixed(2);

        assert.equal(tokens, should_tokens, text);
        assert.equal(odd_ethers, should_odd_ethers, textOdd);
    };

    beforeEach(async function () {
        startTime1 = web3.eth.getBlock('latest').timestamp + duration.weeks(1);

        sale = await Crowdsale.new(startTime1, wallet);
        token = await Token.at(await sale.token());
    })
  
    it("token.totalSupply → Check balance and totalSupply before donate", async () => {
        assert.equal((await token.balanceOf(client1)).toNumber(), 0, "balanceOf must be 0 on the start");
        assert.equal((await token.totalSupply()).toNumber(), 0, "totalSupply must be 0 on the start");
    });

    it("running → check PreICO is started", async() => {
        assert.equal((await sale.running()), false);
        await increaseTime(duration.weeks(1));
        assert.equal((await sale.running()), true);
    });

    it("calcAmountAt → PreITO", async() => {
        await check_calcAmount(1e18, startTime1, 600e18);
    });

    it("token.transfer → forbidden transfer and transferFrom until ITO", async() => {
        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e18, gas: 120000});

        await shouldHaveException(async () => {
            await token.transfer(client1, 1e8, {from: client1});
        }, "Should has an error");

        await shouldHaveException(async () => {
            await token.transferFrom(client1, client1, 1e8, {from: client1});
        }, "Should has an error");

        await shouldHaveException(async () => {
            await sale.refund({from: client1});
        }, "Should has an error");
    });

    it("token.transfer → forbidden transfer token after ITO", async () => {
        let maxWei = await sale.hardCapInWei();

        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: maxWei, gas: 120000});

        await sale.finishCrowdsale();

        assert.equal((await token.mintingFinished()), true, 'token.mintingFinished should true');


        await shouldHaveException(async () => {
            await token.transfer(client2, 1e18, {from: client1});
        }, "Should has an error");
    });

    it("minimalTokenPrice → do not allow to sell less than minimalTokenPrice", async() => {
        await increaseTime(duration.weeks(1));

        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e17, gas: 120000});

        await shouldHaveException(async () => {
            await web3.eth.sendTransaction({from: client1, to: sale.address, value: 0.0001e18, gas: 120000});
        }, "Should has an error");
    });

    it("withdraw → check ether transfer to wallet", async() => {
        let balance1, balance2, balance3;

        balance1 = await web3.eth.getBalance(wallet);
        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e18, gas: 120000});
        balance2 = await web3.eth.getBalance(wallet);

            assert.equal(Math.round((balance2 - balance1)/1e14), 1e4);
    });

    it("finishCrowdsale → finish minting", async() => {
        let tokenOnClient, totalSupply;

        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 10e18, gas: 120000});

        tokenOnClient = (await token.balanceOf(client1)).toNumber();
        totalSupply = (await token.totalSupply()).toNumber();
        assert.equal(((totalSupply)/1e18).toFixed(4), (tokenOnClient/1e18).toFixed(4));

        await increaseTime(duration.days(91));
        await sale.finishCrowdsale();
        assert.equal((await token.mintingFinished()), true);
    });

    it("buyTokens → received lower than 0.0001 ether", async() => {

        await increaseTime(duration.weeks(1));

        let token_purchase_events = (await sale.TokenPurchase({fromBlock: 0, toBlock: 'latest'}))

        await sale.buyTokens(client2, {from: client1, value: 1e18});

        token_purchase_events.get((err, events) => {
            assert.equal(events.length, 1);
            assert.equal(events[0].event, 'TokenPurchase');
        });

        await shouldHaveException(async () => {
            console.log(await sale.buyTokens(client2, {from: client1, value: 0.0001e18, gas: 120000}));
        }, "Should has an error");
    });

    it("buyTokens → direct call", async() => {
        await increaseTime(duration.weeks(1));

        let client2_balance = (await token.balanceOf(client2));
        await sale.buyTokens(client2, {from: client1, value: 100e18});
        let client2_balance2 = (await token.balanceOf(client2));
        assert.notEqual(client2_balance, client2_balance2.toNumber());
        let result = await sale.calcAmountAt(100e18, startTime1);
        assert.equal(client2_balance2.toNumber(), result[0]);
        assert.equal(0, result[1]);
    });

    it("send → Check token balance", async() => {
        await increaseTime(duration.weeks(1));

        await balanceEqualTo(client1, 0);

        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e18, gas: 120000});

        await balanceEqualTo(client1, 600e18);
    });

    it("send → After donate", async () => {
        await balanceEqualTo(client1, 0);
        await increaseTime(duration.weeks(1));

        let initialTotalSupply = (await token.totalSupply()).toNumber();

        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e18, gas: 120000});

        assert.equal(
            ((initialTotalSupply + 600e18)/1e18).toFixed(4),
            ((await token.totalSupply()).toNumber()/1e18).toFixed(4),
            "Client balance must be 1 ether / testRate"
        );
        await balanceEqualTo(client1, 600e18);
    });

    it("send → Donate before Pre-ITO startTime", async () => {
        await shouldHaveException(async () => {
            await web3.eth.sendTransaction({from: client1, to: sale.address, value: 4e18, gas: 120000});
        }, "Should has an error");
    });

    it("send → Donate after Pre-ITO startTime", async () => {
        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: 1e18, gas: 120000});
    });

    it("send → Donate between Pre-ITO and ITO", async () => {
        await increaseTime(duration.weeks(1) + duration.days(30));
        await shouldHaveException(async () => {
            await web3.eth.sendTransaction({from: client1, to: sale.address, value: 4e18, gas: 120000});
        }, "Should has an error");
    });

    it("send → Donate max ether for Pre-ITO", async () => {
        let started_balance = (await web3.eth.getBalance(wallet)).toNumber();
        let maxWei = await sale.hardCapInWei();
        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: maxWei, gas: 120000});
        let end_balance = (await web3.eth.getBalance(wallet)).toNumber();
        assert.equal(
            Math.round(maxWei.toNumber()/1e18),
            Math.round((end_balance-started_balance)/1e18)
        );
    });

    it("send → Donate more then max ether for Pre-ITO", async () => {
        let started_balance = await web3.eth.getBalance(wallet);
        let started_client_balance = await web3.eth.getBalance(client1);
        let maxWei = await sale.hardCapInWei();

        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: maxWei + 1e18, gas: 120000});

        let end_balance = await web3.eth.getBalance(wallet);
        let end_client_balance = await web3.eth.getBalance(client1);

        assert.equal(
            Math.round(maxWei.toNumber()/1e18),
            Math.round((end_balance.sub(started_balance))/1e18)
        );
        assert.equal(
            Math.round((started_client_balance.sub(end_client_balance))/1e18),
            Math.round((maxWei.toNumber())/1e18)
        );
    });

    it("send → Donate after endTime", async () => {
        await increaseTime(duration.days(120));

        await shouldHaveException(async () => {
            await web3.eth.sendTransaction({from: client, to: sale.address, value: 4e18, gas: 120000});
        }, "Should has an error");

        await sale.finishCrowdsale();
        assert.equal((await token.mintingFinished()), true, 'mintingFinished must true');
    });

    it("finishMinting → test", async () => {
        let end_balance, tokenOnClientWallet, totalSupply;
        let started_balance = (await web3.eth.getBalance(wallet)).toNumber();
        let maxWei = await sale.hardCapInWei();

        await increaseTime(duration.weeks(1));
        await web3.eth.sendTransaction({from: client1, to: sale.address, value: maxWei, gas: 120000});

        await sale.finishCrowdsale();

        await shouldHaveException(async () => {
            await sale.finishCrowdsale();
        }, "Should has an error");

        assert.equal((await token.mintingFinished()), true);

        totalSupply = (await token.totalSupply()).toNumber();
        end_balance = (await web3.eth.getBalance(wallet)).toNumber();
        assert.equal(Math.round((end_balance - started_balance)/1e18), Math.round(maxWei/1e18));

        // token on client wallet
        tokenOnClientWallet = (await token.balanceOf(client1)).toNumber();
        assert.equal(Math.round((totalSupply)/1e14), Math.round(tokenOnClientWallet/1e14));
    });

});

