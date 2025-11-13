// Ant Attack 3D Level Editor
// Canvas-based map editor for creating custom levels

console.log('=== Ant Attack 3D Level Editor Loading ===');

// Map configuration
const MAP_WIDTH = 60;
const MAP_HEIGHT = 60;
const MAX_LEVELS = 6;

// Canvas settings
const canvas = document.getElementById('mapCanvas');
if (!canvas) {
    console.error('FATAL: mapCanvas element not found!');
} else {
    console.log('Canvas element found:', canvas);
}
const ctx = canvas.getContext('2d');
const CELL_SIZE = 10; // Pixels per grid cell

// State
let currentLayer = 0;
let currentTool = 'place';
let isDrawing = false;
let currentRotation = 0; // 0=North, 1=East, 2=South, 3=West (clockwise)

// Drag preview state
let dragPreviewPos = null; // {x, y} grid position of drag preview
let dragPreviewShape = null; // shape type being dragged
let dragPreviewSize = null; // size of shape being dragged
let dragPreviewRotation = 0; // rotation of drag preview

// Map data structure: blocks[x][y][z] where z is height
let blocks = [];
let ramps = [];

// Initialize empty map
function initializeMap() {
    blocks = [];
    for (let x = 0; x < MAP_WIDTH; x++) {
        blocks[x] = [];
        for (let y = 0; y < MAP_HEIGHT; y++) {
            blocks[x][y] = [];
            for (let z = 0; z < MAX_LEVELS; z++) {
                blocks[x][y][z] = false;
            }
        }
    }
    ramps = [];
    updateStats();
    render();
}

// Get the footprint dimensions for a shape
function getShapeFootprint(shapeType, size, rotation = 0) {
    let width, height;
    
    switch (shapeType) {
        case 'pyramid':
            width = size;
            height = size;
            break;
        case 'arch':
            width = size;
            height = 1;
            break;
        case 'tower':
            width = 3;
            height = 3;
            break;
        case 'platform':
            width = size;
            height = size;
            break;
        case 'wall':
            width = size;
            height = 1;
            break;
        case 'stairs':
            width = size;
            height = 1;
            break;
        default:
            width = 1;
            height = 1;
    }
    
    // Swap width and height for East/West rotations (90° and 270°)
    if (rotation === 1 || rotation === 3) {
        return { width: height, height: width };
    }
    
    return { width, height };
}

// Render the current layer
function render() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw grid
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
    ctx.lineWidth = 1;
    
    for (let x = 0; x <= MAP_WIDTH; x++) {
        ctx.beginPath();
        ctx.moveTo(x * CELL_SIZE, 0);
        ctx.lineTo(x * CELL_SIZE, MAP_HEIGHT * CELL_SIZE);
        ctx.stroke();
    }
    
    for (let y = 0; y <= MAP_HEIGHT; y++) {
        ctx.beginPath();
        ctx.moveTo(0, y * CELL_SIZE);
        ctx.lineTo(MAP_WIDTH * CELL_SIZE, y * CELL_SIZE);
        ctx.stroke();
    }
    
    // Draw blocks at current layer
    for (let x = 0; x < MAP_WIDTH; x++) {
        for (let y = 0; y < MAP_HEIGHT; y++) {
            if (blocks[x][y][currentLayer]) {
                ctx.fillStyle = '#3498db';
                ctx.fillRect(x * CELL_SIZE + 1, y * CELL_SIZE + 1, CELL_SIZE - 2, CELL_SIZE - 2);
            }
            
            // Show blocks below current layer (dimmed)
            if (currentLayer > 0) {
                for (let z = 0; z < currentLayer; z++) {
                    if (blocks[x][y][z]) {
                        const alpha = 0.1 + (z / currentLayer) * 0.2;
                        ctx.fillStyle = `rgba(52, 152, 219, ${alpha})`;
                        ctx.fillRect(x * CELL_SIZE + 1, y * CELL_SIZE + 1, CELL_SIZE - 2, CELL_SIZE - 2);
                        break; // Only show highest block below
                    }
                }
            }
        }
    }
    
    // Draw ramps at current layer
    ramps.forEach(ramp => {
        if (ramp.z === currentLayer) {
            ctx.fillStyle = '#e67e22';
            ctx.fillRect(ramp.x * CELL_SIZE + 1, ramp.y * CELL_SIZE + 1, CELL_SIZE - 2, CELL_SIZE - 2);
            
            // Draw direction indicator
            ctx.fillStyle = '#fff';
            ctx.font = '8px Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            const arrows = ['↓', '←', '↑', '→'];
            ctx.fillText(arrows[ramp.direction], (ramp.x + 0.5) * CELL_SIZE, (ramp.y + 0.5) * CELL_SIZE);
        }
    });
    
    // Draw drag preview outline
    if (dragPreviewPos && dragPreviewShape && dragPreviewSize) {
        const footprint = getShapeFootprint(dragPreviewShape, dragPreviewSize, dragPreviewRotation);
        
        // Draw semi-transparent fill
        ctx.fillStyle = 'rgba(46, 204, 113, 0.2)';
        ctx.fillRect(
            dragPreviewPos.x * CELL_SIZE,
            dragPreviewPos.y * CELL_SIZE,
            footprint.width * CELL_SIZE,
            footprint.height * CELL_SIZE
        );
        
        // Draw bright outline
        ctx.strokeStyle = '#2ecc71';
        ctx.lineWidth = 2;
        ctx.strokeRect(
            dragPreviewPos.x * CELL_SIZE,
            dragPreviewPos.y * CELL_SIZE,
            footprint.width * CELL_SIZE,
            footprint.height * CELL_SIZE
        );
        
        // Draw rotation indicator (arrow)
        const rotationArrows = ['→', '↓', '←', '↑']; // North, East, South, West
        ctx.fillStyle = '#2ecc71';
        ctx.font = 'bold 12px Arial';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        const labelX = (dragPreviewPos.x + footprint.width / 2) * CELL_SIZE;
        const labelY = (dragPreviewPos.y + footprint.height / 2) * CELL_SIZE;
        ctx.fillText(`${dragPreviewShape} (${dragPreviewSize}) ${rotationArrows[dragPreviewRotation]}`, labelX, labelY);
    }
}

// Get grid coordinates from mouse event
function getGridCoords(event) {
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((event.clientX - rect.left) / CELL_SIZE);
    const y = Math.floor((event.clientY - rect.top) / CELL_SIZE);
    
    if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
        return { x, y };
    }
    return null;
}

// Update cursor position display
function updateCursorDisplay(coords) {
    if (coords) {
        document.getElementById('cursorPos').textContent = `${coords.x}, ${coords.y}`;
    } else {
        document.getElementById('cursorPos').textContent = '--, --';
    }
}

// Place or remove block
function setBlock(x, y, z, value) {
    if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT && z >= 0 && z < MAX_LEVELS) {
        blocks[x][y][z] = value;
        updateStats();
        render();
    }
}

// Add ramp
function addRamp(x, y, z) {
    const direction = parseInt(document.getElementById('rampDirection').value);
    const isShallow = document.getElementById('shallowRamp').checked;
    
    // Check if ramp already exists at this position
    const existingIndex = ramps.findIndex(r => r.x === x && r.y === y && r.z === z);
    if (existingIndex >= 0) {
        ramps.splice(existingIndex, 1);
    }
    
    ramps.push({
        x: x,
        y: y,
        z: z,
        direction: direction,
        width: 1,
        height: 1,
        isShallow: isShallow
    });
    
    updateStats();
    render();
}

// Remove ramp at position
function removeRamp(x, y, z) {
    const index = ramps.findIndex(r => r.x === x && r.y === y && r.z === z);
    if (index >= 0) {
        ramps.splice(index, 1);
        updateStats();
        render();
    }
}

// Update statistics display
function updateStats() {
    let blockCount = 0;
    for (let x = 0; x < MAP_WIDTH; x++) {
        for (let y = 0; y < MAP_HEIGHT; y++) {
            for (let z = 0; z < MAX_LEVELS; z++) {
                if (blocks[x][y][z]) blockCount++;
            }
        }
    }
    
    document.getElementById('blockCount').textContent = blockCount;
    document.getElementById('rampCount').textContent = ramps.length;
}

// Canvas event handlers
canvas.addEventListener('mousedown', (e) => {
    isDrawing = true;
    const coords = getGridCoords(e);
    if (coords) {
        handleCanvasClick(coords.x, coords.y);
    }
});

canvas.addEventListener('mousemove', (e) => {
    const coords = getGridCoords(e);
    updateCursorDisplay(coords);
    
    // Update drag preview if we're dragging a shape
    if (draggedShape && coords) {
        dragPreviewPos = coords;
        dragPreviewShape = draggedShape;
        dragPreviewSize = currentShapeConfig.size;
        dragPreviewRotation = currentRotation;
        render(); // Re-render to show preview
    } else {
        dragPreviewPos = null;
        dragPreviewShape = null;
        dragPreviewSize = null;
        dragPreviewRotation = 0;
    }
    
    if (isDrawing && coords) {
        handleCanvasClick(coords.x, coords.y);
    }
});

canvas.addEventListener('mouseup', () => {
    isDrawing = false;
});

canvas.addEventListener('mouseleave', () => {
    isDrawing = false;
    updateCursorDisplay(null);
});

// Handle click/drag on canvas
function handleCanvasClick(x, y) {
    switch (currentTool) {
        case 'place':
            setBlock(x, y, currentLayer, true);
            break;
        case 'remove':
            setBlock(x, y, currentLayer, false);
            removeRamp(x, y, currentLayer);
            break;
        case 'ramp':
            addRamp(x, y, currentLayer);
            break;
    }
}

// Tool selection
function selectTool(tool) {
    currentTool = tool;
    
    // Update UI
    document.querySelectorAll('.tool-button').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelector(`[data-tool="${tool}"]`).classList.add('active');
    
    const toolNames = {
        'place': 'Place Block',
        'remove': 'Remove Block',
        'ramp': 'Place Ramp'
    };
    document.getElementById('currentTool').textContent = toolNames[tool];
    setStatus(`Tool changed to: ${toolNames[tool]}`);
}

// Layer control
function changeLayer(delta) {
    const newLayer = currentLayer + delta;
    if (newLayer >= 0 && newLayer < MAX_LEVELS) {
        currentLayer = newLayer;
        document.getElementById('currentLayer').textContent = `Layer: ${currentLayer}`;
        render();
        setStatus(`Changed to layer ${currentLayer}`);
    }
}

// Status message
function setStatus(message) {
    document.getElementById('statusMessage').textContent = message;
}

// Predefined shapes
function placeShape(shapeType) {
    // Prompt for position
    const x = parseInt(prompt('Enter X position (0-59):', '20'));
    const y = parseInt(prompt('Enter Y position (0-59):', '20'));
    
    if (isNaN(x) || isNaN(y) || x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT) {
        setStatus('Invalid position');
        return;
    }
    
    switch (shapeType) {
        case 'pyramid':
            placePyramid(x, y);
            break;
        case 'arch':
            placeArch(x, y);
            break;
        case 'tower':
            placeTower(x, y);
            break;
        case 'platform':
            placePlatform(x, y);
            break;
        case 'wall':
            placeWall(x, y);
            break;
        case 'stairs':
            placeStairs(x, y);
            break;
    }
    
    setStatus(`Placed ${shapeType} at (${x}, ${y})`);
}

// Shape placement functions
function placePyramid(startX, startY, size = 5) {
    // Create a step pyramid with steps on all sides
    // Each level is centered and smaller than the one below
    for (let level = 0; level < size && level < MAX_LEVELS; level++) {
        const width = size - (level * 2);
        if (width <= 0) break; // Stop if pyramid is complete
        
        const offset = level; // Center offset for this level
        
        for (let dx = 0; dx < width; dx++) {
            for (let dy = 0; dy < width; dy++) {
                const x = startX + offset + dx;
                const y = startY + offset + dy;
                if (x < MAP_WIDTH && y < MAP_HEIGHT) {
                    blocks[x][y][level] = true;
                }
            }
        }
    }
    updateStats();
    render();
}

function placeArch(startX, startY, size = 6, rotation = 0) {
    const width = size;
    const height = Math.min(Math.floor(size * 0.67), MAX_LEVELS);
    
    // Rotation: 0=North(horizontal), 1=East(vertical), 2=South(horizontal), 3=West(vertical)
    const isVertical = (rotation === 1 || rotation === 3);
    
    if (isVertical) {
        // Vertical arch (rotated 90° or 270°)
        // Left pillar
        for (let z = 0; z < height; z++) {
            if (startX < MAP_WIDTH && startY < MAP_HEIGHT) {
                blocks[startX][startY][z] = true;
            }
        }
        
        // Right pillar
        for (let z = 0; z < height; z++) {
            const y = startY + width - 1;
            if (startX < MAP_WIDTH && y < MAP_HEIGHT) {
                blocks[startX][y][z] = true;
            }
        }
        
        // Top span
        if (height - 1 < MAX_LEVELS) {
            for (let dy = 0; dy < width; dy++) {
                const y = startY + dy;
                if (startX < MAP_WIDTH && y < MAP_HEIGHT) {
                    blocks[startX][y][height - 1] = true;
                }
            }
        }
    } else {
        // Horizontal arch (original orientation)
        // Left pillar
        for (let z = 0; z < height; z++) {
            if (startX < MAP_WIDTH && startY < MAP_HEIGHT) {
                blocks[startX][startY][z] = true;
            }
        }
        
        // Right pillar
        for (let z = 0; z < height; z++) {
            const x = startX + width - 1;
            if (x < MAP_WIDTH && startY < MAP_HEIGHT) {
                blocks[x][startY][z] = true;
            }
        }
        
        // Top span
        if (height - 1 < MAX_LEVELS) {
            for (let dx = 0; dx < width; dx++) {
                const x = startX + dx;
                if (x < MAP_WIDTH && startY < MAP_HEIGHT) {
                    blocks[x][startY][height - 1] = true;
                }
            }
        }
    }
    
    updateStats();
    render();
}

function placeTower(startX, startY, size = 5) {
    const width = 3;
    const height = Math.min(size, MAX_LEVELS);
    
    for (let z = 0; z < height; z++) {
        for (let dx = 0; dx < width; dx++) {
            for (let dy = 0; dy < width; dy++) {
                const x = startX + dx;
                const y = startY + dy;
                if (x < MAP_WIDTH && y < MAP_HEIGHT) {
                    blocks[x][y][z] = true;
                }
            }
        }
    }
    updateStats();
    render();
}

function placePlatform(startX, startY, size = 8) {
    const z = 0;
    for (let dx = 0; dx < size; dx++) {
        for (let dy = 0; dy < size; dy++) {
            const x = startX + dx;
            const y = startY + dy;
            if (x < MAP_WIDTH && y < MAP_HEIGHT) {
                blocks[x][y][z] = true;
            }
        }
    }
    updateStats();
    render();
}

function placeWall(startX, startY, size = 10, rotation = 0) {
    const length = size;
    const height = 2;
    
    // Rotation: 0=North(horizontal X), 1=East(vertical Y), 2=South(horizontal X), 3=West(vertical Y)
    const isVertical = (rotation === 1 || rotation === 3);
    
    if (isVertical) {
        // Vertical wall (along Y axis)
        for (let dy = 0; dy < length; dy++) {
            for (let z = 0; z < height && z < MAX_LEVELS; z++) {
                const y = startY + dy;
                if (startX < MAP_WIDTH && y < MAP_HEIGHT) {
                    blocks[startX][y][z] = true;
                }
            }
        }
    } else {
        // Horizontal wall (along X axis)
        for (let dx = 0; dx < length; dx++) {
            for (let z = 0; z < height && z < MAX_LEVELS; z++) {
                const x = startX + dx;
                if (x < MAP_WIDTH && startY < MAP_HEIGHT) {
                    blocks[x][startY][z] = true;
                }
            }
        }
    }
    
    updateStats();
    render();
}

function placeStairs(startX, startY, size = 5, rotation = 0) {
    const steps = Math.min(size, MAX_LEVELS);
    
    // Rotation: 0=North(X+), 1=East(Y+), 2=South(X-), 3=West(Y-)
    
    for (let step = 0; step < steps; step++) {
        let x, y;
        
        switch (rotation) {
            case 0: // North - stairs go along +X axis
                x = startX + step;
                y = startY;
                break;
            case 1: // East - stairs go along +Y axis
                x = startX;
                y = startY + step;
                break;
            case 2: // South - stairs go along -X axis (reversed)
                x = startX - step;
                y = startY;
                break;
            case 3: // West - stairs go along -Y axis (reversed)
                x = startX;
                y = startY - step;
                break;
        }
        
        if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
            for (let z = 0; z <= step; z++) {
                blocks[x][y][z] = true;
            }
        }
    }
    
    updateStats();
    render();
}

// Add border wall around the map edge
function addBorderWall() {
    let blocksAdded = 0;
    
    // Add blocks along all four edges at height 0 (layer 0)
    for (let x = 0; x < MAP_WIDTH; x++) {
        // Top edge (y = 0)
        if (!blocks[x][0][0]) {
            blocks[x][0][0] = true;
            blocksAdded++;
        }
        // Bottom edge (y = MAP_HEIGHT - 1)
        if (!blocks[x][MAP_HEIGHT - 1][0]) {
            blocks[x][MAP_HEIGHT - 1][0] = true;
            blocksAdded++;
        }
    }
    
    for (let y = 1; y < MAP_HEIGHT - 1; y++) {
        // Left edge (x = 0)
        if (!blocks[0][y][0]) {
            blocks[0][y][0] = true;
            blocksAdded++;
        }
        // Right edge (x = MAP_WIDTH - 1)
        if (!blocks[MAP_WIDTH - 1][y][0]) {
            blocks[MAP_WIDTH - 1][y][0] = true;
            blocksAdded++;
        }
    }
    
    updateStats();
    render();
    setStatus(`Added border wall (${blocksAdded} blocks)`);
}

function clearLayer() {
    if (confirm(`Clear all blocks on layer ${currentLayer}?`)) {
        for (let x = 0; x < MAP_WIDTH; x++) {
            for (let y = 0; y < MAP_HEIGHT; y++) {
                blocks[x][y][currentLayer] = false;
            }
        }
        
        // Remove ramps on this layer
        ramps = ramps.filter(r => r.z !== currentLayer);
        
        updateStats();
        render();
        setStatus(`Cleared layer ${currentLayer}`);
    }
}

function clearAll() {
    if (confirm('Clear entire map? This cannot be undone!')) {
        initializeMap();
        setStatus('Map cleared');
    }
}

// Map management
function newMap() {
    if (confirm('Create new map? Any unsaved changes will be lost.')) {
        initializeMap();
        setStatus('New map created');
    }
}

function saveMap() {
    document.getElementById('saveModal').classList.add('show');
    document.getElementById('mapName').value = '';
    document.getElementById('mapName').focus();
}

function closeSaveModal() {
    document.getElementById('saveModal').classList.remove('show');
}

async function confirmSave() {
    const mapName = document.getElementById('mapName').value.trim();
    
    if (!mapName) {
        alert('Please enter a map name');
        return;
    }
    
    const mapData = {
        name: mapName,
        width: MAP_WIDTH,
        height: MAP_HEIGHT,
        maxLevels: MAX_LEVELS,
        blocks: blocks,
        ramps: ramps,
        createdAt: new Date().toISOString()
    };
    
    try {
        const response = await fetch('/api/maps', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(mapData)
        });
        
        if (response.ok) {
            setStatus(`Map "${mapName}" saved successfully`);
            closeSaveModal();
        } else {
            const error = await response.text();
            alert(`Failed to save map: ${error}`);
        }
    } catch (err) {
        alert(`Error saving map: ${err.message}`);
    }
}

async function loadMap() {
    try {
        const response = await fetch('/api/maps');
        const maps = await response.json();
        
        if (maps.length === 0) {
            alert('No saved maps found');
            return;
        }
        
        // Create selection dialog
        let mapList = 'Available maps:\n\n';
        maps.forEach((map, index) => {
            mapList += `${index + 1}. ${map.name}\n`;
        });
        mapList += '\nEnter map number to load:';
        
        const selection = prompt(mapList);
        const index = parseInt(selection) - 1;
        
        if (index >= 0 && index < maps.length) {
            const mapName = maps[index].name;
            const mapResponse = await fetch(`/api/maps/${encodeURIComponent(mapName)}`);
            const mapData = await mapResponse.json();
            
            // Load map data
            blocks = mapData.blocks;
            ramps = mapData.ramps;
            currentLayer = 0;
            
            updateStats();
            render();
            document.getElementById('currentLayer').textContent = `Layer: ${currentLayer}`;
            setStatus(`Loaded map: ${mapName}`);
        }
    } catch (err) {
        alert(`Error loading map: ${err.message}`);
    }
}

// ============================================
// SHAPE SELECTOR WITH VISUAL PREVIEW
// ============================================

let currentShapeConfig = { type: 'pyramid', size: 5 };
const shapeSelector = document.getElementById('shapeSelector');
const shapeSelectorTitle = document.getElementById('shapeSelectorTitle');
const shapeOptions = document.getElementById('shapeOptions');

// Configuration for each shape type
const shapeConfigs = {
    pyramid: {
        title: 'Select Pyramid Size',
        options: [
            { size: 3, label: 'Small' },
            { size: 5, label: 'Medium' },
            { size: 7, label: 'Large' },
            { size: 9, label: 'Huge' },
            { size: 11, label: 'Massive' },
            { size: 13, label: 'Giant' }
        ]
    },
    tower: {
        title: 'Select Tower Height',
        options: [
            { size: 3, label: '3 Floors' },
            { size: 4, label: '4 Floors' },
            { size: 5, label: '5 Floors' },
            { size: 6, label: '6 Floors' }
        ]
    },
    arch: {
        title: 'Select Arch Size',
        options: [
            { size: 4, label: 'Small' },
            { size: 6, label: 'Medium' },
            { size: 8, label: 'Large' }
        ]
    },
    platform: {
        title: 'Select Platform Size',
        options: [
            { size: 5, label: '5×5' },
            { size: 8, label: '8×8' },
            { size: 10, label: '10×10' },
            { size: 15, label: '15×15' },
            { size: 20, label: '20×20' }
        ]
    },
    wall: {
        title: 'Select Wall Length',
        options: [
            { size: 5, label: '5 units' },
            { size: 10, label: '10 units' },
            { size: 15, label: '15 units' },
            { size: 20, label: '20 units' }
        ]
    },
    stairs: {
        title: 'Select Stair Length',
        options: [
            { size: 4, label: '4 Steps' },
            { size: 5, label: '5 Steps' },
            { size: 6, label: '6 Steps' }
        ]
    }
};

// Draw visual preview on canvas
function drawShapePreview(canvas, shapeType, size) {
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;
    
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#3498db';
    ctx.strokeStyle = '#2980b9';
    ctx.lineWidth = 1;
    
    const centerX = w / 2;
    const centerY = h / 2;
    const scale = Math.min(w, h) / (size + 2);
    
    switch (shapeType) {
        case 'pyramid':
            // Draw isometric pyramid (largest at bottom, smallest at top)
            // Each level shrinks by 2 blocks on each side (4 total)
            const blockHeight = scale * 0.8;
            for (let level = 0; level < size; level++) {
                const width = (size - level * 2) * scale;
                if (width <= 0) break; // Stop if pyramid is complete
                
                // Start from bottom of canvas and work up
                const y = h - 10 - (level + 1) * blockHeight;
                
                ctx.fillStyle = `hsl(210, 70%, ${40 + level * 8}%)`;
                ctx.fillRect(centerX - width / 2, y, width, blockHeight);
                ctx.strokeRect(centerX - width / 2, y, width, blockHeight);
            }
            break;
            
        case 'tower':
            // Draw vertical tower
            const towerWidth = scale * 2;
            const towerBlockHeight = (h - 10) / size;
            for (let i = 0; i < size; i++) {
                ctx.fillStyle = `hsl(210, 70%, ${40 + i * 10}%)`;
                ctx.fillRect(centerX - towerWidth / 2, h - 5 - (i + 1) * towerBlockHeight, towerWidth, towerBlockHeight);
                ctx.strokeRect(centerX - towerWidth / 2, h - 5 - (i + 1) * towerBlockHeight, towerWidth, towerBlockHeight);
            }
            break;
            
        case 'arch':
            // Draw arch shape
            const archWidth = size * scale * 0.8;
            const archHeight = size * scale * 0.6;
            ctx.fillStyle = '#3498db';
            // Left pillar
            ctx.fillRect(centerX - archWidth / 2, centerY, scale, archHeight);
            // Right pillar
            ctx.fillRect(centerX + archWidth / 2 - scale, centerY, scale, archHeight);
            // Top beam
            ctx.fillRect(centerX - archWidth / 2, centerY - scale, archWidth, scale);
            ctx.strokeRect(centerX - archWidth / 2, centerY - scale, archWidth, archHeight + scale);
            break;
            
        case 'platform':
            // Draw flat platform
            const platSize = Math.min(w - 10, h - 10);
            ctx.fillStyle = '#3498db';
            ctx.fillRect(centerX - platSize / 2, centerY - platSize / 2, platSize, platSize);
            ctx.strokeRect(centerX - platSize / 2, centerY - platSize / 2, platSize, platSize);
            // Add grid lines
            ctx.strokeStyle = '#2980b9';
            const gridSize = platSize / 4;
            for (let i = 1; i < 4; i++) {
                ctx.beginPath();
                ctx.moveTo(centerX - platSize / 2 + i * gridSize, centerY - platSize / 2);
                ctx.lineTo(centerX - platSize / 2 + i * gridSize, centerY + platSize / 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(centerX - platSize / 2, centerY - platSize / 2 + i * gridSize);
                ctx.lineTo(centerX + platSize / 2, centerY - platSize / 2 + i * gridSize);
                ctx.stroke();
            }
            break;
            
        case 'wall':
            // Draw horizontal wall
            const wallWidth = w - 10;
            const wallHeight = h / 3;
            ctx.fillStyle = '#3498db';
            ctx.fillRect(5, centerY - wallHeight / 2, wallWidth, wallHeight);
            ctx.strokeRect(5, centerY - wallHeight / 2, wallWidth, wallHeight);
            break;
            
        case 'stairs':
            // Draw stairs ascending
            const stepWidth = (w - 10) / size;
            const stepHeight = (h - 10) / size;
            for (let i = 0; i < size; i++) {
                ctx.fillStyle = `hsl(210, 70%, ${40 + i * 10}%)`;
                ctx.fillRect(5 + i * stepWidth, h - 5 - (i + 1) * stepHeight, stepWidth, (i + 1) * stepHeight);
                ctx.strokeRect(5 + i * stepWidth, h - 5 - (i + 1) * stepHeight, stepWidth, (i + 1) * stepHeight);
            }
            break;
    }
}

// Show shape selector popup
function showShapeSelector(button, shapeType) {
    const config = shapeConfigs[shapeType];
    if (!config) return;
    
    // Update title
    shapeSelectorTitle.textContent = config.title;
    
    // Clear existing options
    shapeOptions.innerHTML = '';
    
    // Create option buttons with previews
    config.options.forEach(option => {
        const optionDiv = document.createElement('div');
        optionDiv.className = 'shape-option';
        
        const canvas = document.createElement('canvas');
        canvas.width = 80;
        canvas.height = 80;
        drawShapePreview(canvas, shapeType, option.size);
        
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = option.label;
        
        optionDiv.appendChild(canvas);
        optionDiv.appendChild(label);
        
        // Make the option div draggable
        optionDiv.draggable = true;
        optionDiv.style.cursor = 'grab';
        
        // Handle drag start from size option
        optionDiv.addEventListener('dragstart', (e) => {
            console.log('Drag started from size option:', shapeType, option.size);
            
            // Hide the popup immediately
            hideShapeSelector();
            
            // Set the dragged shape and size
            draggedShape = shapeType;
            currentShapeConfig = { type: shapeType, size: option.size };
            
            // Initialize drag preview rotation
            dragPreviewRotation = currentRotation;
            
            // Show rotation overlay for asymmetric shapes
            if (['arch', 'wall', 'stairs'].includes(shapeType)) {
                showRotationOverlay();
            }
            
            optionDiv.style.cursor = 'grabbing';
            e.dataTransfer.effectAllowed = 'copy';
            e.dataTransfer.setData('text/plain', shapeType);
            
            const rotationNames = ['→', '↓', '←', '↑'];
            setStatus(`Dragging ${option.label} ${shapeType} (size: ${option.size}) ${rotationNames[currentRotation]} - Click buttons to rotate`);
        });
        
        optionDiv.addEventListener('dragend', (e) => {
            optionDiv.style.cursor = 'grab';
            console.log('Drag ended from size option');
            
            // Hide rotation overlay
            hideRotationOverlay();
            
            // Delay resetting draggedShape to allow drop event to process first
            setTimeout(() => {
                draggedShape = null;
            }, 100);
        });
        
        // Keep click handler for selecting without dragging
        optionDiv.addEventListener('click', () => {
            currentShapeConfig = { type: shapeType, size: option.size };
            shapeSelector.classList.remove('show');
            setStatus(`Selected ${option.label} ${shapeType} (size: ${option.size}) - ready to drag`);
        });
        
        shapeOptions.appendChild(optionDiv);
    });
    
    // Position popup near button
    const rect = button.getBoundingClientRect();
    shapeSelector.style.left = `${rect.right + 10}px`;
    shapeSelector.style.top = `${rect.top}px`;
    shapeSelector.classList.add('show');
}

// Hide shape selector
function hideShapeSelector() {
    shapeSelector.classList.remove('show');
}

// Set up shape button hover handlers
document.querySelectorAll('.shape-button').forEach(button => {
    const shapeType = button.getAttribute('data-shape');
    
    button.addEventListener('mouseenter', () => {
        showShapeSelector(button, shapeType);
    });
    
    button.addEventListener('mouseleave', (e) => {
        // Check if mouse is moving to the selector popup
        const rect = shapeSelector.getBoundingClientRect();
        const x = e.clientX;
        const y = e.clientY;
        
        if (!(x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom)) {
            setTimeout(() => {
                if (!shapeSelector.matches(':hover')) {
                    hideShapeSelector();
                }
            }, 200);
        }
    });
});

// Hide selector when mouse leaves it
shapeSelector.addEventListener('mouseleave', () => {
    hideShapeSelector();
});

// ============================================
// DRAG AND DROP FUNCTIONALITY
// ============================================

let draggedShape = null;

// Set up drag and drop for shape buttons
console.log('Setting up drag and drop handlers for', document.querySelectorAll('.shape-button').length, 'shape buttons');
document.querySelectorAll('.shape-button').forEach(button => {
    console.log('Attaching dragstart handler to button:', button.getAttribute('data-shape'));
    
    // Test if mousedown fires
    button.addEventListener('mousedown', (e) => {
        console.log('MOUSEDOWN on button:', button.getAttribute('data-shape'), 'button:', e.button);
    });
    
    button.addEventListener('mouseup', (e) => {
        console.log('MOUSEUP on button:', button.getAttribute('data-shape'));
    });
    
    button.addEventListener('click', (e) => {
        console.log('CLICK on button:', button.getAttribute('data-shape'));
    });
    
    button.addEventListener('dragstart', (e) => {
        // Hide the shape selector popup immediately when drag starts
        hideShapeSelector();
        
        draggedShape = e.target.getAttribute('data-shape');
        e.target.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'copy';
        e.dataTransfer.setData('text/plain', draggedShape);
        
        // Auto-set currentShapeConfig if user didn't click a size option
        // Use the first (default) size option for the dragged shape
        if (currentShapeConfig.type !== draggedShape) {
            const config = shapeConfigs[draggedShape];
            if (config && config.options.length > 0) {
                currentShapeConfig = { type: draggedShape, size: config.options[0].size };
                console.log('Auto-selected default size for', draggedShape, ':', currentShapeConfig);
            }
        }
        
        // Initialize drag preview rotation
        dragPreviewRotation = currentRotation;
        
        // Show rotation overlay for asymmetric shapes
        if (['arch', 'wall', 'stairs'].includes(draggedShape)) {
            showRotationOverlay();
        }
        
        const rotationNames = ['→', '↓', '←', '↑'];
        console.log('Drag started:', draggedShape, 'currentShapeConfig:', currentShapeConfig, 'rotation:', currentRotation);
        setStatus(`Dragging ${draggedShape} (${currentShapeConfig.size}) ${rotationNames[currentRotation]} - Click buttons to rotate`);
    });
    
    button.addEventListener('dragend', (e) => {
        e.target.classList.remove('dragging');
        console.log('Drag ended');
        
        // Hide rotation overlay
        hideRotationOverlay();
        
        // Delay resetting draggedShape to allow drop event to process first
        setTimeout(() => {
            draggedShape = null;
        }, 100);
    });
});

// 2D Canvas drop handlers
canvas.addEventListener('dragover', (e) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    canvas.classList.add('drag-over');
    
    // Update drag preview position
    if (draggedShape) {
        const coords = getGridCoords(e);
        if (coords) {
            dragPreviewPos = coords;
            dragPreviewShape = draggedShape;
            dragPreviewSize = currentShapeConfig.size;
            dragPreviewRotation = currentRotation;
            render(); // Re-render to show preview
        }
    }
});

canvas.addEventListener('dragleave', (e) => {
    canvas.classList.remove('drag-over');
    
    // Clear drag preview
    dragPreviewPos = null;
    dragPreviewShape = null;
    dragPreviewSize = null;
    render(); // Re-render to hide preview
});

canvas.addEventListener('drop', (e) => {
    e.preventDefault();
    canvas.classList.remove('drag-over');
    
    console.log('2D canvas drop event fired, draggedShape:', draggedShape);
    
    // Clear drag preview
    dragPreviewPos = null;
    dragPreviewShape = null;
    dragPreviewSize = null;
    
    if (!draggedShape) return;
    
    // Get canvas coordinates
    const rect = canvas.getBoundingClientRect();
    const canvasX = e.clientX - rect.left;
    const canvasY = e.clientY - rect.top;
    
    // Convert to grid coordinates
    const gridX = Math.floor(canvasX / CELL_SIZE);
    const gridY = Math.floor(canvasY / CELL_SIZE);
    
    console.log('Drop at grid position:', gridX, gridY, 'currentShapeConfig:', currentShapeConfig);
    
    if (gridX >= 0 && gridX < MAP_WIDTH && gridY >= 0 && gridY < MAP_HEIGHT) {
        placeShapeAt(draggedShape, gridX, gridY);
        setStatus(`Placed ${draggedShape} at (${gridX}, ${gridY})`);
    } else {
        setStatus('Invalid drop position');
    }
    
    render(); // Re-render to clear preview and show placed shape
});

// 3D Canvas drop handlers
const canvas3D = document.getElementById('preview3D');
let raycaster, mouse3D;

canvas3D.addEventListener('dragover', (e) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    canvas3D.classList.add('drag-over');
});

canvas3D.addEventListener('dragleave', (e) => {
    canvas3D.classList.remove('drag-over');
});

canvas3D.addEventListener('drop', (e) => {
    e.preventDefault();
    canvas3D.classList.remove('drag-over');
    
    console.log('3D canvas drop event fired, draggedShape:', draggedShape);
    
    if (!draggedShape) return;
    
    // Get 3D coordinates using raycasting
    const rect = canvas3D.getBoundingClientRect();
    mouse3D = mouse3D || new THREE.Vector2();
    raycaster = raycaster || new THREE.Raycaster();
    
    // Convert mouse position to normalized device coordinates (-1 to +1)
    mouse3D.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse3D.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    
    // Update raycaster
    raycaster.setFromCamera(mouse3D, camera);
    
    // Create a ground plane at y=0 to intersect with
    const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
    const intersectPoint = new THREE.Vector3();
    raycaster.ray.intersectPlane(groundPlane, intersectPoint);
    
    console.log('3D intersectPoint:', intersectPoint);
    
    if (intersectPoint) {
        const gridX = Math.floor(intersectPoint.x);
        const gridY = Math.floor(intersectPoint.z);
        
        console.log('3D drop at grid position:', gridX, gridY, 'currentShapeConfig:', currentShapeConfig);
        
        if (gridX >= 0 && gridX < MAP_WIDTH && gridY >= 0 && gridY < MAP_HEIGHT) {
            placeShapeAt(draggedShape, gridX, gridY);
            setStatus(`Placed ${draggedShape} at (${gridX}, ${gridY}) via 3D view`);
        } else {
            setStatus('Invalid drop position');
        }
    }
});

// Helper function to place shape at specific coordinates
function placeShapeAt(shapeType, x, y) {
    // Use the size from currentShapeConfig if it matches the shape type
    const size = (currentShapeConfig.type === shapeType) ? currentShapeConfig.size : undefined;
    const rotation = currentRotation; // Use current rotation state
    
    console.log('placeShapeAt called:', { shapeType, x, y, size, rotation, currentShapeConfig });
    
    switch (shapeType) {
        case 'pyramid':
            placePyramid(x, y, size);
            break;
        case 'arch':
            placeArch(x, y, size, rotation);
            break;
        case 'tower':
            placeTower(x, y, size);
            break;
        case 'platform':
            placePlatform(x, y, size);
            break;
        case 'wall':
            placeWall(x, y, size, rotation);
            break;
        case 'stairs':
            placeStairs(x, y, size, rotation);
            break;
    }
}

// Initialize
initializeMap();
setStatus('Level editor ready');

// ============================================
// 3D PREVIEW USING THREE.JS
// ============================================

let scene, camera, renderer, controls;
let preview3DObjects = [];
let isDragging3D = false;
let previousMousePosition = { x: 0, y: 0 };
let cameraAngle = 45; // Initial angle in degrees
let cameraDistance = 100;

// Layer visibility for 3D view (default all visible)
let layerVisibility = Array(MAX_LEVELS).fill(true);

function init3DPreview() {
    const canvas3D = document.getElementById('preview3D');
    
    // Create scene
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1a1a2e);
    
    // Create orthographic camera for isometric view (like the game)
    const aspect = canvas3D.width / canvas3D.height;
    const frustumSize = 50;
    camera = new THREE.OrthographicCamera(
        frustumSize * aspect / -2,
        frustumSize * aspect / 2,
        frustumSize / 2,
        frustumSize / -2,
        0.1,
        1000
    );
    
    // Position camera at 45-degree angle for isometric view
    updateCameraPosition();
    camera.lookAt(MAP_WIDTH / 2, 0, MAP_HEIGHT / 2);
    
    // Create renderer
    renderer = new THREE.WebGLRenderer({ canvas: canvas3D, antialias: true });
    renderer.setSize(canvas3D.width, canvas3D.height);
    
    // Add ambient light (increased for better visibility of all faces)
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
    scene.add(ambientLight);
    
    // Add directional light from one side (reduced to add subtle depth without harsh shadows)
    const dirLight1 = new THREE.DirectionalLight(0xffffff, 0.35);
    dirLight1.position.set(50, 50, 50);
    scene.add(dirLight1);
    
    // Add second directional light from opposite side to illuminate all faces
    const dirLight2 = new THREE.DirectionalLight(0xffffff, 0.35);
    dirLight2.position.set(-50, 50, -50);
    scene.add(dirLight2);
    
    // Add ground plane
    const groundGeometry = new THREE.PlaneGeometry(MAP_WIDTH, MAP_HEIGHT);
    const groundMaterial = new THREE.MeshLambertMaterial({ color: 0x8B7355 });
    const ground = new THREE.Mesh(groundGeometry, groundMaterial);
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(MAP_WIDTH / 2, 0, MAP_HEIGHT / 2);
    scene.add(ground);
    
    // Add grid helper
    const gridHelper = new THREE.GridHelper(Math.max(MAP_WIDTH, MAP_HEIGHT), Math.max(MAP_WIDTH, MAP_HEIGHT), 0x444444, 0x222222);
    gridHelper.position.set(MAP_WIDTH / 2, 0.01, MAP_HEIGHT / 2);
    scene.add(gridHelper);
    
    // Mouse controls for rotation
    canvas3D.addEventListener('mousedown', on3DMouseDown);
    canvas3D.addEventListener('mousemove', on3DMouseMove);
    canvas3D.addEventListener('mouseup', on3DMouseUp);
    canvas3D.addEventListener('mouseleave', on3DMouseUp);
    canvas3D.addEventListener('wheel', on3DMouseWheel);
    
    // Initial render
    render3DPreview();
    
    // Initialize layer checkboxes
    initLayerCheckboxes();
}

function initLayerCheckboxes() {
    const container = document.getElementById('layerCheckboxes');
    if (!container) return;
    
    container.innerHTML = '';
    
    for (let i = 0; i < MAX_LEVELS; i++) {
        const div = document.createElement('div');
        div.className = 'layer-checkbox-item';
        
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.id = `layer-${i}`;
        checkbox.checked = true; // Default all visible
        checkbox.addEventListener('change', (e) => {
            layerVisibility[i] = e.target.checked;
            render3DPreview();
        });
        
        const label = document.createElement('label');
        label.htmlFor = `layer-${i}`;
        label.textContent = `Layer ${i}`;
        label.addEventListener('click', (e) => {
            // Prevent double-toggle from checkbox
            e.preventDefault();
            checkbox.checked = !checkbox.checked;
            layerVisibility[i] = checkbox.checked;
            render3DPreview();
        });
        
        div.appendChild(checkbox);
        div.appendChild(label);
        container.appendChild(div);
    }
}

function toggleAllLayers(visible) {
    layerVisibility.fill(visible);
    
    // Update checkboxes
    for (let i = 0; i < MAX_LEVELS; i++) {
        const checkbox = document.getElementById(`layer-${i}`);
        if (checkbox) checkbox.checked = visible;
    }
    
    render3DPreview();
}

function updateCameraPosition() {
    const angleRad = cameraAngle * Math.PI / 180;
    camera.position.set(
        MAP_WIDTH / 2 + Math.cos(angleRad) * cameraDistance,
        cameraDistance * 0.7, // Height
        MAP_HEIGHT / 2 + Math.sin(angleRad) * cameraDistance
    );
    camera.lookAt(MAP_WIDTH / 2, MAX_LEVELS / 2, MAP_HEIGHT / 2);
}

function on3DMouseDown(event) {
    isDragging3D = true;
    previousMousePosition = {
        x: event.clientX,
        y: event.clientY
    };
}

function on3DMouseMove(event) {
    if (!isDragging3D) return;
    
    const deltaX = event.clientX - previousMousePosition.x;
    
    // Rotate camera around the scene
    cameraAngle -= deltaX * 0.5;
    
    updateCameraPosition();
    render3DPreview();
    
    previousMousePosition = {
        x: event.clientX,
        y: event.clientY
    };
}

function on3DMouseUp() {
    isDragging3D = false;
}

function on3DMouseWheel(event) {
    event.preventDefault();
    cameraDistance += event.deltaY * 0.05;
    cameraDistance = Math.max(30, Math.min(150, cameraDistance));
    updateCameraPosition();
    render3DPreview();
}

function render3DPreview() {
    // Clear existing blocks
    preview3DObjects.forEach(obj => scene.remove(obj));
    preview3DObjects = [];
    
    // Block geometry and material
    const blockGeometry = new THREE.BoxGeometry(1, 1, 1);
    const blockMaterial = new THREE.MeshLambertMaterial({ color: 0x3498db });
    
    // Ramp geometry and material
    const rampMaterial = new THREE.MeshLambertMaterial({ color: 0xe67e22 });
    
    // Render all blocks
    for (let x = 0; x < MAP_WIDTH; x++) {
        for (let y = 0; y < MAP_HEIGHT; y++) {
            for (let z = 0; z < MAX_LEVELS; z++) {
                // Only render if block exists AND layer is visible
                if (blocks[x][y][z] && layerVisibility[z]) {
                    const block = new THREE.Mesh(blockGeometry, blockMaterial);
                    block.position.set(x + 0.5, z + 0.5, y + 0.5);
                    scene.add(block);
                    preview3DObjects.push(block);
                }
            }
        }
    }
    
    // Render all ramps
    ramps.forEach(ramp => {
        // Only render if layer is visible
        if (layerVisibility[ramp.z]) {
            // Create a wedge shape for the ramp
            const rampGeometry = createRampGeometry(ramp.direction, ramp.shallow || false);
            const rampMesh = new THREE.Mesh(rampGeometry, rampMaterial);
            
            // Position ramp
            rampMesh.position.set(ramp.x + 0.5, ramp.z + 0.5, ramp.y + 0.5);
            
            scene.add(rampMesh);
            preview3DObjects.push(rampMesh);
        }
    });
    
    renderer.render(scene, camera);
}

function createRampGeometry(direction, shallow) {
    // Create a wedge shape for the ramp
    // Direction: 0=South(+Y), 1=West(-X), 2=North(-Y), 3=East(+X)
    
    const height = shallow ? 0.5 : 1.0;
    const shape = new THREE.Shape();
    
    if (direction === 0) { // South (+Y)
        shape.moveTo(-0.5, -0.5);
        shape.lineTo(0.5, -0.5);
        shape.lineTo(0.5, 0.5);
        shape.lineTo(-0.5, 0.5);
    } else if (direction === 1) { // West (-X)
        shape.moveTo(-0.5, -0.5);
        shape.lineTo(0.5, -0.5);
        shape.lineTo(0.5, 0.5);
        shape.lineTo(-0.5, 0.5);
    } else if (direction === 2) { // North (-Y)
        shape.moveTo(-0.5, -0.5);
        shape.lineTo(0.5, -0.5);
        shape.lineTo(0.5, 0.5);
        shape.lineTo(-0.5, 0.5);
    } else { // East (+X)
        shape.moveTo(-0.5, -0.5);
        shape.lineTo(0.5, -0.5);
        shape.lineTo(0.5, 0.5);
        shape.lineTo(-0.5, 0.5);
    }
    
    // Create wedge geometry
    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array([
        // Bottom face
        -0.5, 0, -0.5,
        0.5, 0, -0.5,
        0.5, 0, 0.5,
        -0.5, 0, 0.5,
        
        // Top edge (sloped)
        -0.5, height, 0.5,
        0.5, height, 0.5
    ]);
    
    const indices = [
        // Bottom
        0, 1, 2,
        0, 2, 3,
        // Front (low side)
        0, 1, 5,
        0, 5, 4,
        // Sides
        1, 2, 5,
        2, 3, 4,
        3, 0, 4,
        // Top slope
        4, 5, 2,
        4, 2, 3
    ];
    
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    
    // Rotate based on direction
    const rotationY = direction * Math.PI / 2;
    geometry.rotateY(rotationY);
    
    return geometry;
}

// Override the render function to also update 3D preview
const originalRender = render;
render = function() {
    originalRender();
    if (typeof renderer !== 'undefined') {
        render3DPreview();
    }
};

// Initialize 3D preview after Three.js loads
if (typeof THREE !== 'undefined') {
    init3DPreview();
} else {
    // Wait for Three.js to load
    window.addEventListener('load', () => {
        setTimeout(init3DPreview, 100);
    });
}

// ============================================
// KEYBOARD SHORTCUTS
// ============================================

document.addEventListener('keydown', (e) => {
    // R key to rotate shapes
    if (e.key === 'r' || e.key === 'R') {
        currentRotation = (currentRotation + 1) % 4;
        dragPreviewRotation = currentRotation;
        
        const rotationNames = ['North →', 'East ↓', 'South ←', 'West ↑'];
        setStatus(`Rotation: ${rotationNames[currentRotation]}`);
        
        // Update rotation overlay buttons
        updateRotationOverlay();
        
        // Update preview if currently dragging
        if (dragPreviewPos) {
            render();
        }
        
        console.log('Rotation changed to:', currentRotation, rotationNames[currentRotation]);
    }
    
    // Reset rotation with Shift+R
    if ((e.key === 'r' || e.key === 'R') && e.shiftKey) {
        currentRotation = 0;
        dragPreviewRotation = 0;
        setStatus('Rotation reset to North →');
        
        // Update rotation overlay buttons
        updateRotationOverlay();
        
        if (dragPreviewPos) {
            render();
        }
    }
});

// ============================================
// ROTATION OVERLAY CONTROLS
// ============================================

function showRotationOverlay() {
    const overlay = document.getElementById('rotationOverlay');
    if (overlay) {
        overlay.classList.add('show');
        updateRotationOverlay();
    }
}

function hideRotationOverlay() {
    const overlay = document.getElementById('rotationOverlay');
    if (overlay) {
        overlay.classList.remove('show');
    }
}

function updateRotationOverlay() {
    const buttons = document.querySelectorAll('.rotation-btn');
    buttons.forEach(btn => {
        const rotation = parseInt(btn.getAttribute('data-rotation'));
        if (rotation === currentRotation) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
}

function setRotation(rotation) {
    currentRotation = rotation;
    dragPreviewRotation = rotation;
    
    const rotationNames = ['North →', 'East ↓', 'South ←', 'West ↑'];
    setStatus(`Rotation: ${rotationNames[currentRotation]}`);
    
    // Update overlay buttons
    updateRotationOverlay();
    
    // Update preview if currently dragging
    if (dragPreviewPos) {
        render();
    }
    
    console.log('Rotation set to:', currentRotation, rotationNames[currentRotation]);
}
