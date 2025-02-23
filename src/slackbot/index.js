const { App } = require('@slack/bolt');
const k8s = require('@kubernetes/client-node');
require('dotenv').config();

// Initialize Slack app
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  socketMode: true,
  appToken: process.env.SLACK_APP_TOKEN
});

// Initialize Kubernetes client
const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const k8sApi = kc.makeApiClient(k8s.AppsV1Api);

// Command: Get service status
app.command('/service-status', async ({ command, ack, respond }) => {
  await ack();
  try {
    const namespace = 'prod';
    const response = await k8sApi.listNamespacedDeployment(namespace);
    const deployments = response.body.items.map(item => ({
      name: item.metadata.name,
      replicas: `${item.status.readyReplicas || 0}/${item.status.replicas}`,
      status: item.status.conditions?.[0]?.status || 'Unknown'
    }));

    const message = {
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Service Status*'
          }
        },
        ...deployments.map(dep => ({
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `*${dep.name}*\nReplicas: ${dep.replicas}\nStatus: ${dep.status}`
          }
        }))
      ]
    };

    await respond(message);
  } catch (error) {
    await respond({
      text: `Error getting service status: ${error.message}`
    });
  }
});

// Command: Restart service
app.command('/restart-service', async ({ command, ack, respond }) => {
  await ack();
  const serviceName = command.text.trim();
  
  if (!serviceName) {
    await respond({
      text: 'Please provide a service name to restart'
    });
    return;
  }

  try {
    const namespace = 'prod';
    const deployment = await k8sApi.readNamespacedDeployment(serviceName, namespace);
    
    // Trigger a rolling restart by patching the deployment
    const patch = {
      spec: {
        template: {
          metadata: {
            annotations: {
              'kubectl.kubernetes.io/restartedAt': new Date().toISOString()
            }
          }
        }
      }
    };

    await k8sApi.patchNamespacedDeployment(
      serviceName,
      namespace,
      patch,
      undefined,
      undefined,
      undefined,
      undefined,
      { headers: { 'Content-Type': 'application/strategic-merge-patch+json' } }
    );

    await respond({
      text: `Service ${serviceName} restart initiated`
    });
  } catch (error) {
    await respond({
      text: `Error restarting service: ${error.message}`
    });
  }
});

// Command: Scale service
app.command('/scale-service', async ({ command, ack, respond }) => {
  await ack();
  const [serviceName, replicas] = command.text.split(' ');
  
  if (!serviceName || !replicas) {
    await respond({
      text: 'Please provide both service name and number of replicas'
    });
    return;
  }

  const replicaCount = parseInt(replicas, 10);
  if (isNaN(replicaCount)) {
    await respond({
      text: 'Please provide a valid number for replicas'
    });
    return;
  }

  try {
    const namespace = 'prod';
    const patch = {
      spec: {
        replicas: replicaCount
      }
    };

    await k8sApi.patchNamespacedDeployment(
      serviceName,
      namespace,
      patch,
      undefined,
      undefined,
      undefined,
      undefined,
      { headers: { 'Content-Type': 'application/strategic-merge-patch+json' } }
    );

    await respond({
      text: `Service ${serviceName} scaled to ${replicaCount} replicas`
    });
  } catch (error) {
    await respond({
      text: `Error scaling service: ${error.message}`
    });
  }
});

// Start the app
(async () => {
  await app.start(process.env.PORT || 3000);
  console.log('⚡️ Slack bot is running!');
})(); 