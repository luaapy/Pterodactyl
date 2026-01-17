<?php

require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Pterodactyl\Models\Node;
use Symfony\Component\Yaml\Yaml;

// Fetch Node
$nodeName = getenv('NODE_NAME');

try {
    $node = Node::where('name', $nodeName)->firstOrFail();
} catch (\Exception $e) {
    fwrite(STDERR, "Node not found: $nodeName\n");
    exit(1);
}

// Generate Config
// Note: $node->daemon_token is automatically decrypted by Eloquent casts
$config = [
    'debug' => false,
    'uuid' => $node->uuid,
    'token_id' => $node->daemon_token_id,
    'token' => $node->daemon_token,
    'api' => [
        'host' => '0.0.0.0',
        'port' => (int) $node->daemon_listen,
        'ssl' => [
            'enabled' => false,
        ],
        'upload_limit' => 100,
    ],
    'system' => [
        'data' => '/var/lib/pterodactyl/volumes',
        'sftp' => [
            'bind_port' => (int) $node->daemon_sftp,
        ],
    ],
    'allowed_mounts' => [],
    'remote' => 'http://panel:80',
];

// Output YAML
echo Yaml::dump($config, 4, 2);
