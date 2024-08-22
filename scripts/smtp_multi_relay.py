#
# smtp_multi_relay.py - SMTP relay to duplicate mails up-to 10 times
#
# Intended to run in Docker container with env vars:
#   LISTEN_PORT (defaults to 25)
#   TARGET_HOST_0 ... TARGET_HOST_9
#   TARGET_PORT_0 ... TARGET_PORT_9 (defaults to 25)
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

import os
import asyncio
import smtplib
import logging
from aiosmtpd.controller import Controller
from aiosmtpd.smtp import Envelope

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ForwardingHandler:
    def __init__(self, targets):
        self.targets = targets

    async def handle_DATA(self, server, session, envelope: Envelope):
        for target in self.targets:
            try:
                self.forward_email(envelope, target)
                logger.info(f"Email forwarded to {target['host']}:{target['port']}")
            except Exception as e:
                logger.error(f"Failed to forward email to {target['host']}:{target['port']}: {e}")
        return '250 Message accepted for delivery'

    def forward_email(self, envelope: Envelope, target):
        with smtplib.SMTP(target['host'], target['port']) as smtp:
            smtp.sendmail(envelope.mail_from, envelope.rcpt_tos, envelope.content)


if __name__ == '__main__':
    # Read target hosts and ports from environment variables
    targets = []

    for i in range(10):
        target_host = os.getenv(f'TARGET_HOST_{i}')
        target_port = int(os.getenv(f'TARGET_PORT_{i}', 25))

        if target_host:
            targets.append({'host': target_host, 'port': target_port})

    # Ensure at least one target is defined
    if not targets:
        raise ValueError("No valid targets configured for SMTP relay")

    # Create and start the SMTP relay
    handler = ForwardingHandler(targets)
    listen_port = int(os.getenv('LISTEN_PORT', 25))
    controller = Controller(handler, hostname='0.0.0.0', port=listen_port)
    controller.start()

    logger.info(f"SMTP relay running on port {listen_port} and forwarding emails...")
    try:
        asyncio.get_event_loop().run_forever()
    except KeyboardInterrupt:
        pass
    finally:
        controller.stop()
