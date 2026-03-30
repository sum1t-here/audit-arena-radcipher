# 🔐 RadCipher Guild — Weekly Audit Contest Submissions

> Smart contract security audit findings by **Sumit** ([@sum1t_here](https://twitter.com/sum1t_here))  
> Competing on the [RadCipher Guild](https://radcipher.com/) weekly audit arena.

---

## About This Repo

This repository contains my weekly audit contest submissions for the **RadCipher Guild** — a structured competitive audit program where participants find, document, and submit security vulnerabilities in Solidity smart contracts.

Each week a new protocol is scoped. Findings are categorized by severity, backed by a written report, and supported by Foundry PoC tests.

---

## Methodology

1. **Manual review** — read the protocol spec and contracts line by line
2. **Static analysis** — run [Aderyn](https://github.com/Cyfrin/aderyn) for automated detection
3. **Threat modeling** — identify trust assumptions, external calls, state transitions
4. **PoC writing** — every Medium+ finding is backed by a Foundry test that proves impact
5. **Report writing** — structured findings with description, impact, PoC, and recommendation

---

## Severity Definitions

| Severity      | Definition |
|---------------|------------|
| 🔴 High       | Direct loss of funds or complete protocol compromise |
| 🟠 Medium     | Conditional loss of funds, DoS, or significant functionality break |
| 🟡 Low        | Minor spec violations, edge cases, or limited impact issues |
| ℹ️ Informational | Code quality, gas optimizations, best practice violations |

---

## Submissions

| Week | Protocol | Findings | Report |
|------|----------|----------|--------|
| Week 9 | BatchRefundCrowdfund | 1M / 2L | [report](findings/week-9/report.md) |

---

## Tools Used

- [Foundry](https://book.getfoundry.sh/) — testing and PoC development
- [Aderyn](https://github.com/Cyfrin/aderyn) — static analysis
- Manual review

---

## Running Tests

```bash
# clone the repo
git clone https://github.com/sum1t-here/<repo-name>
cd <repo-name>

# install dependencies
forge install

# run all tests
forge test

# run specific week
forge test --match-path test/week-9/week-9.t.sol -vvv

# run specific test
forge test --match-test test_DOS_attack -vvv
```

---

## About Me

I'm a smart contract security auditor and fullstack developer based in Guwahati, India, currently specializing in DeFi security (NFT Marketplaces → Lending/Borrowing → ERC20 Vaults).

- 🐦 Twitter: [@sum1t_here](https://twitter.com/sum1t_here)
- 🐙 GitHub: [@sum1t-here](https://github.com/sum1t-here)
- 🏆 Platforms: [Solodit](https://solodit.xyz) · [CodeHawks](https://codehawks.com)

---

## Disclaimer

All findings in this repository are submitted as part of competitive audit contests. Reports are for educational purposes and reflect my independent analysis during the contest window. They are not a guarantee of security.