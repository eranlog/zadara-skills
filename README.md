# zadara-skills

Claude Code skills for Zadara QA infrastructure.

## Skills

| Skill                                     | Description                                           |
|-------------------------------------------|-------------------------------------------------------|
| [ssh-ccvm](skills/ssh-ccvm/SKILL.md)      | SSH into CCVM via CCMaster jump host                  |
| [zadara-ssh](skills/zadara-ssh/SKILL.md)  | SSH into any Zadara node: CCMaster, SN, CCVM, VPSA VC |
| [logs](skills/logs/SKILL.md)              | Tail Zadara logs on VC, SN, or CCMaster               |
| [zsnap](skills/zsnap/SKILL.md)            | Collect diagnostic snapshots and upload to S3         |

## Installation

```bash
cd ~/.claude/plugins
git clone https://github.com/eranlog/zadara-skills
```

Restart Claude Code — skills load automatically.
