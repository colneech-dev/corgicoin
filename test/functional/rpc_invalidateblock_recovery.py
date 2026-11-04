#!/usr/bin/env python3
"""A node that dies between saving an invalidation and rolling back finishes the rollback at startup.

invalidateblock saves its marker first and rolls the chain back second. If the process stops in between
(power cut, kill -9), the node restarts with a best block inside the chain it was told to reject. The
regtest-only -testcrashafterinvalidate flag makes the daemon exit at exactly that point.
"""
from test_framework import CorgiTestFramework, assert_equal


class InvalidateBlockRecoveryTest(CorgiTestFramework):
    num_nodes = 1

    def run_test(self):
        node = self.nodes[0]
        node.generate(20)
        target = node.getblockhash(12)
        old_tip = node.getbestblockhash()
        assert_equal(node.getblockcount(), 20)

        self.log("the node dies after saving the invalidation and before rolling back")
        node.stop()
        node.start(["-testcrashafterinvalidate=1"])
        try:
            node.invalidateblock(target)
        except Exception:
            pass  # the connection drops when the daemon exits mid-call
        node.process.wait(timeout=60)
        assert_equal(node.process.returncode, 1)

        self.log("on restart the rollback is finished")
        node.start()
        assert_equal(node.getblockcount(), 11)
        assert_equal(node.getbestblockhash(), node.getblockhash(11))
        tips = {t["hash"]: t["status"] for t in node.getchaintips()}
        assert_equal(tips[old_tip], "invalid")
        with open(node.debug_log, errors="replace") as f:
            assert "RecoverInvalidatedTip" in f.read(), "startup recovery did not run"

        self.log("the node can mine on from there")
        node.generate(1)
        assert_equal(node.getblockcount(), 12)
        assert node.getbestblockhash() != old_tip

        self.log("a further restart has nothing to recover")
        tip = node.getbestblockhash()
        node.stop()
        node.start()
        assert_equal(node.getbestblockhash(), tip)
        assert_equal(node.getblockcount(), 12)


if __name__ == "__main__":
    InvalidateBlockRecoveryTest().main()
