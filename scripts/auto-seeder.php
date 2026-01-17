<?php

require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Pterodactyl\Models\User;
use Pterodactyl\Models\Location;
use Pterodactyl\Models\Node;
use Pterodactyl\Models\Allocation;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

echo "🚀 Starting Auto-Seeder...\n";

// --- 1. Create Admin User ---
$email = getenv('ADMIN_EMAIL');
$user = User::where('email', $email)->first();

if (!$user) {
    $user = new User();
    $user->email = $email;
    $user->username = getenv('ADMIN_USERNAME');
    $user->password = Hash::make(getenv('ADMIN_PASSWORD'));
    $user->name_first = getenv('ADMIN_FIRST_NAME');
    $user->name_last = getenv('ADMIN_LAST_NAME');
    $user->root_admin = true;
    $user->language = 'en';
    $user->uuid = Str::uuid()->toString();
    $user->save();
    echo "✅ Admin user created: {$email}\n";
} else {
    echo "ℹ️ Admin user already exists.\n";
}

// --- 2. Create Location ---
$locationShort = 'local';
$location = Location::where('short', $locationShort)->first();

if (!$location) {
    $location = new Location();
    $location->short = $locationShort;
    $location->long = getenv('NODE_LOCATION');
    $location->save();
    echo "✅ Location created: {$location->long}\n";
} else {
    echo "ℹ️ Location already exists.\n";
}

// --- 3. Create Node ---
$nodeName = getenv('NODE_NAME');
$node = Node::where('name', $nodeName)->first();

if (!$node) {
    $node = new Node();
    $node->name = $nodeName;
    $node->description = "Auto-configured node for GitHub Codespaces";
    $node->location_id = $location->id;
    $node->public = true;
    $node->fqdn = getenv('NODE_FQDN');
    $node->scheme = getenv('NODE_SCHEME');
    $node->behind_proxy = true;
    $node->maintenance_mode = false;
    $node->memory = (int) getenv('NODE_MEMORY');
    $node->memory_overallocate = 0;
    $node->disk = (int) getenv('NODE_DISK');
    $node->disk_overallocate = 0;
    $node->upload_size = 100;
    $node->daemonListen = (int) getenv('NODE_DAEMON_LISTEN');
    $node->daemonSFTP = (int) getenv('NODE_DAEMON_SFTP');
    $node->daemonBase = '/var/lib/pterodactyl/volumes';
    $node->uuid = Str::uuid()->toString();
    $node->daemon_token_id = Str::random(16);
    $node->daemon_token = Str::random(64);
    $node->save();
    echo "✅ Node created: {$nodeName} (ID: {$node->id})\n";
} else {
    echo "ℹ️ Node already exists.\n";
}

// --- 4. Create Allocations ---
$ports = explode(',', getenv('ALLOCATION_PORTS'));
$count = 0;

foreach ($ports as $port) {
    $port = trim($port);
    if (empty($port)) continue;

    $exists = Allocation::where('node_id', $node->id)
        ->where('ip', '0.0.0.0')
        ->where('port', $port)
        ->exists();

    if (!$exists) {
        $allocation = new Allocation();
        $allocation->node_id = $node->id;
        $allocation->ip = '0.0.0.0';
        $allocation->port = $port;
        $allocation->ip_alias = null;
        $allocation->server_id = null;
        $allocation->save();
        $count++;
    }
}

if ($count > 0) {
    echo "✅ Created {$count} allocations.\n";
} else {
    echo "ℹ️ Allocations already exist.\n";
}

echo "✨ Auto-Seeder completed successfully!\n";
