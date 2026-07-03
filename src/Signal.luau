--!optimize 2
--!strict

--[[
BSD Zero Clause License

Copyright (c) 2026 6inch9inch

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
]]--

--[[
SomeSignal, signal which attempts to fix issues with roblox signals.
With priority connection support allowing you to choose which connections
are more important than others (Connecting speeds will be cursed at large amounts though)
]]--

-- Current version of this module is 2.5.2

--[[
Note from creator:
This does work on both new and old type solver, although beware that on old solver
the self argument for signal methods / signal value in connection is `any`
Also, thanks MaddestCat for helping with this along the way
]]--

-- Sorry for whoever is reading the source code types,
-- but that's the only way to have comments in functions
export type Connection<A... = ()> = {
  _next: Connection<A...>?,
  _priorityNext: Connection<A...>?,
  _prev: Connection<A...>?,
  _priorityPrev: Connection<A...>?,
  _signal: Signal<A...>,
  _func: (A...) -> (),
  _isInCreationQueue: boolean?,
  _deferredPriority: number?, 
  Connected: boolean,
  Priority: number, -- Determined by DEFAULT_PRIORITY
  ChangePriority: typeof(
    -- <strong><em>If signal is firing</strong></em>, then it's <strong><em>deferred for current connection</strong></em> and <strong><em>immediate for nested connection</strong></em>
    -- Otherwise, it's immediate
    function(self: Connection<A...>, priority: number?)
    end
  ),
  Disconnect: typeof(
    -- <strong><em>If signal is firing and it's mode is set to default</strong></em>, then it's <strong><em>deferred for current connection</strong></em> and <strong><em>immediate for nested connection</strong></em>
    -- Otherwise, it's immediate
    function(self: Connection<A...>, mode: ("default" | "immediate")?)
    end
  )
}
export type Signal<A... = ()> = {
  _head: Connection<A...>?,
  _priorityHead: Connection<A...>?,
  _tail: Connection<A...>?,
  _priorityTail: Connection<A...>?,
  Connect: typeof(
    -- Creates a connection to the signal
    function(self: Signal<A...>, func: (A...) -> (), priority: number?): Connection<A...> 
      return {}:: any 
    end
  ),
  Once: typeof(
    -- Creates a one-time connection to the signal
    function(self: Signal<A...>, func: (A...) -> (), priority: number?): Connection<A...> 
      return {}:: any 
    end
  ),
  Wait: typeof(
    -- Creates a one-time connection to the signal and yields the thread until it receives given parameters or gets timed out 
    -- @Param connectionPointer: A empty table which inherits connection data, has a niche use-case
    function(self: Signal<A...>, timeout: number?, priority: number?, connectionPointer: Connection<A...>?): A...
      return coroutine.yield()
    end
  ),
  Fire: typeof(
    -- Calls all connections
    -- <strong>Reentrant fires yield the thread until they can get resumed</strong>
    function(self: Signal<A...>, ...: A...): () 
    end
  ),
  SyncFire: typeof(
    -- Calls all connections synchronously, any yielding operations will yield this function
    -- Doesn't respect firing signal and does instant mutations if there's no firing signal
    function(self: Signal<A...>, ...: A...): () 
    end
  ),
  PriorityFire: typeof(
    -- Calls all connections from <strong>highest to lowest priority</strong>
    -- <strong>Reentrant fires yield the thread until they can get resumed</strong>
    function(self: Signal<A...>, ...: A...): () 
    end
  ),
  SyncPriorityFire: typeof(
    -- Calls all connections from <strong>highest to lowest priority</strong> synchronously, any yielding operations will yield this function
    -- Doesn't respect firing signal and does instant mutations if there's no firing signal
    -- You should avoid using this if there's <strong>ChangePriority or Connect/Once/Wait function</strong> in your connections
    function(self: Signal<A...>, ...: A...): () 
    end
  ),
  DisconnectAll: typeof(
    -- <strong><em>If signal is firing and it's mode is set to default</strong></em>, then it defer disconnects current connections and immediately disconnects nested connections
    -- Otherwise, it acts like <strong>DisconnectCurrentConnections</strong>
    function(self: Signal<A...>, mode: ("default" | "immediate")?): ()
    end
  ),
  DisconnectCurrentConnections: typeof(
    -- Default mode is <strong>deferred</strong> if signal is firing
    -- Otherwise, its immediate
    function(self: Signal<A...>, mode: ("deferred" | "immediate")?)
    end
  ),
  DisconnectNestedConnections: typeof(
    -- Default mode is <strong>immediate</strong> if signal is firing
    -- Otherwise, it does nothing
    function(self: Signal<A...>, mode: ("deferred" | "immediate" | "both")?)
    end
  ),
  CancelAllMutations: typeof(
    -- Cancels queued mutations from signal, <strong>deferred</strong> by default if signal is firing
    -- Otherwise, it does nothing
    function(self: Signal<A...>, mode: ("deferred" | "immediate" | "both")?): ()
    end
  )
}

local DEFAULT_PRIORITY = 1 -- You shouldn't touch it, but you do you
local DISCONNECT_CURRENT = 1
local DISCONNECT_NESTED = 2
local DISCONNECT_EVERYTHING = 3
local CANCEL_QUEUE = 4

local threads = {}:: {thread}
local firingSignal = nil:: Signal?
local sharedQueue = {}:: {Connection | (self: Connection, signal: Signal) -> ()} -- Shared queue amongst all signals (this is possible thanks to serial CPU threading)
local sharedDisconnectAllStates = {}:: {[Signal?]: number?}
local sharedFiringQueue = {
  head = 1,
  tail = 0,
  items = {}:: {thread}
}

local function callAndRecycleThread(func: (...any) -> (), thread: thread, ...)
  func(...)
  table.insert(threads, thread)
end

local function createSuspendedThread(func: (...any) -> (), thread: thread, ...)
  func(...)
  table.insert(threads, thread)
  while true do
    callAndRecycleThread(coroutine.yield())
  end
end

local function getThread(): thread
  local threadLen = #threads
  local thread = nil
  if (threadLen ~= 0) then
    thread = threads[threadLen]
    threads[threadLen] = nil
  else
    thread = coroutine.create(createSuspendedThread)
  end
  return thread
end

local function helperUnlink(self: Connection, signal: Signal)
  self.Connected = false
  local next = self._next
  local priorityNext = self._priorityNext
  local previous = self._prev
  local priorityPrevious = self._priorityPrev

  if (next) then
    next._prev = previous
  else
    signal._tail = previous
  end
  if (previous) then
    previous._next = next
  else
    signal._head = next
  end

  if (priorityNext) then
    priorityNext._priorityPrev = priorityPrevious
  else
    signal._priorityTail = priorityPrevious
  end
  if (priorityPrevious) then
    priorityPrevious._priorityNext = priorityNext
  else
    signal._priorityHead = priorityNext
  end

end

local function putInPriority(self: Signal, connection: Connection, priority: number)
  -- Higher priority is on the tail side, head side has lower priority
  -- also we treating sorting like if it's a new connection, so it goes
  -- closest possible to head of the signal

  -- quick way to determine if we can just put it normally in
  local head = self._priorityHead:: Connection
  if (head.Priority == DEFAULT_PRIORITY and priority == DEFAULT_PRIORITY) then
    connection._priorityNext = head
    head._priorityPrev = connection
    self._priorityHead = connection
    return
  end

  local link: Connection?
  local tail = self._priorityTail:: Connection
  if (priority > DEFAULT_PRIORITY) then
    link = tail
    while (link) do
      if (link.Priority < priority) then
        break
      end
      link = link._priorityPrev
    end

    if (link) then
      -- you get the deal, there's a possiblity that it's on the tail side of the signal
      local next = link._priorityNext
      if (next == nil) then
        self._priorityTail = connection
      end
      connection._priorityNext = next
      connection._priorityPrev = link
      link._priorityNext = connection
    else
      -- reached head of the signal
      connection._priorityNext = head
      head._priorityPrev = connection
      self._priorityHead = connection
    end
  else
    link = head
    while (link) do
      if (link.Priority >= priority) then
        break
      end
      link = link._priorityNext
    end

    if (link) then
      -- there's a possibility that it's on the head side of the signal
      local prev = link._priorityPrev
      if (prev == nil) then
        self._priorityHead = connection
      end
      connection._priorityPrev = prev
      connection._priorityNext = link
      link._priorityPrev = connection
    else
      -- we reached the tail, so off we go
      connection._priorityPrev = tail
      tail._priorityNext = connection
      self._priorityTail = connection
    end
  end
end

local function helperDisconnectCurrentConnections(self: Signal)
  local link = self._tail
  while (link) do
    link.Connected = false
    link = link._prev
  end
  self._head, self._tail = nil, nil
  self._priorityHead, self._priorityTail = nil, nil
end

-- if signal is firing and it's behavior is default, then it defer disconnects current connection and immediately disconnects nested connection
-- otherwise, it's immediate
local function disconnect(self: Connection, type: ("default" | "immediate")?)
  local signal = self._signal:: Signal
  if (not self.Connected) then
    return
  elseif (firingSignal) then
    if (self._isInCreationQueue) then
      self.Connected = false
      return
    elseif (type == "immediate") then
      helperUnlink(self, signal)
      return
    end
    table.insert(sharedQueue, self)
    table.insert(sharedQueue, helperUnlink)
    return
  end
  helperUnlink(self, signal)
end


local function helperChangePriority(self: Connection, signal: Signal)  
  local priorityPrevious = self._priorityPrev
  local priorityNext = self._priorityNext

  -- moving this here because I couldn't assure that in changePriority
  if (priorityNext == nil and priorityPrevious == nil) then
    return
  end

  -- Disconnect from priority linked list
  if (priorityNext) then
    priorityNext._priorityPrev = priorityPrevious
  else
    signal._priorityTail = priorityPrevious
  end
  if (priorityPrevious) then
    priorityPrevious._priorityNext = priorityNext
  else
    signal._priorityHead = priorityNext
  end
  putInPriority(signal, self, self.Priority)
end

-- if signal is firing then it's deferred for current connection and immediate for nested connection
-- otherwise, it's immediate
local function changePriority(self: Connection, priority: number?)
  local signal = self._signal:: Signal
  local chosenPriority = priority or DEFAULT_PRIORITY

  if (not self.Connected or self.Priority == chosenPriority) then
    return
  elseif (firingSignal) then
    if (self._isInCreationQueue) then
      self.Priority = chosenPriority
      return
    else
      self._deferredPriority = chosenPriority
    end
    table.insert(sharedQueue, self)
    table.insert(sharedQueue, helperChangePriority)
    return
  end

  self.Priority = chosenPriority
  helperChangePriority(self, signal)
end

local function onNewConnection(self: Connection, signal: Signal)  
  local head = signal._head
  local priorityHead = signal._priorityHead
  self._isInCreationQueue = nil
  self._next = head

  if (head) then
    head._prev = self
  else
    signal._tail = self
  end
  signal._head = self

  if (priorityHead) then
    putInPriority(signal, self, self.Priority)
  else
    signal._priorityTail = self
    signal._priorityHead = self
  end
end

local function newConnection(tbl: Connection, signal: Signal, func: () -> (), priority: number?)
  local chosenPriority = priority or DEFAULT_PRIORITY
  tbl._func = func
  tbl._signal = signal
  tbl.Priority = chosenPriority
  tbl.Connected = true
  tbl.Disconnect = disconnect
  tbl.ChangePriority = changePriority
  return tbl:: Connection
end

local function Connect(self: Signal, func: () -> (), priority: number?)
  local connection = newConnection({}:: Connection, self, func, priority)
  if (firingSignal) then
    connection._isInCreationQueue = true
    table.insert(sharedQueue, connection)
    table.insert(sharedQueue, onNewConnection)
    return connection
  end
  onNewConnection(connection, self)
  return connection
end

local function Once(self: Signal, func: () -> (), priority: number?)
  local connection: Connection
  local onceFunc = function(...)
    helperUnlink(connection, self)
    func(...)
  end
  connection = newConnection({}:: Connection, self, onceFunc, priority)
  if (firingSignal) then
    connection._isInCreationQueue = true
    table.insert(sharedQueue, connection)
    table.insert(sharedQueue, onNewConnection)
    return connection
  end
  onNewConnection(connection, self)
  return connection
end

local function Wait(self: Signal, timeout: number?, priority: number?, connectionPointer: Connection?)
  local thread = coroutine.running()
  local timeoutThread = nil
  local connection: Connection
  local func = function(...)
    helperUnlink(connection, self)
    if (timeoutThread) then
      task.cancel(timeoutThread)
    end
    if (coroutine.status(thread) == "suspended") then
      coroutine.resume(thread, ...)
    end
  end
  connection = newConnection(connectionPointer or {}:: Connection, self, func, priority)
  if (timeout) then
    timeoutThread = task.delay(timeout, function()
      warn("Timeout exceeded, disconnecting")
      connection:Disconnect()
      if (coroutine.status(thread) == "suspended") then
        coroutine.resume(thread)
      end
    end)
  end
  if (firingSignal) then
    connection._isInCreationQueue = true
    table.insert(sharedQueue, connection)
    table.insert(sharedQueue, onNewConnection)
    return coroutine.yield(thread)
  end
  onNewConnection(connection, self)
  return coroutine.yield(thread)
end

local function enqueue(thread: thread)
  sharedFiringQueue.tail += 1
  table.insert(sharedFiringQueue.items, thread)
  return coroutine.yield(thread)
end

local function processDisconnectState(self: Signal)
  local state = sharedDisconnectAllStates[self]

  if (state ~= CANCEL_QUEUE) then
    local len = #sharedQueue
    local transfer = table.create(len):: {Connection | (self: Connection, signal: Signal) -> ()}
    for signal, statev in sharedDisconnectAllStates do
      if (statev == DISCONNECT_CURRENT or statev == DISCONNECT_EVERYTHING) then
        helperDisconnectCurrentConnections(signal:: Signal)
      end
    end
    for i = 1, len, 2 do
      local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()
      local connection = sharedQueue[i]:: Connection
      local statev = sharedDisconnectAllStates[connection._signal]

      local deferredPriority = connection._deferredPriority
      if (deferredPriority) then
        connection.Priority = deferredPriority
        connection._deferredPriority = nil
      end

      if (mutation == onNewConnection and (statev == DISCONNECT_NESTED or statev == DISCONNECT_EVERYTHING)) then
        connection.Connected = false
      elseif (connection.Connected) then
        table.insert(transfer, connection)
        table.insert(transfer, mutation)
      end
    end
    sharedQueue = transfer
  else
    for i = 1, #sharedQueue, 2 do
      local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()
      if (mutation == onNewConnection) then
        local connection = sharedQueue[i]:: Connection
        connection.Connected = false
      end
    end
  end
  table.clear(sharedDisconnectAllStates)

  return state
end

local function dequeue(self: Signal): thread?
  local head, tail = sharedFiringQueue.head, sharedFiringQueue.tail
  local items = sharedFiringQueue.items
  if (head <= tail) then
    local thread = items[head]
    items[head] = nil
    head += 1
    if (head > tail) then
      sharedFiringQueue.head = 1
      sharedFiringQueue.tail = 0
    else
      sharedFiringQueue.head = head
    end
    return thread
  end
  return nil
end

local function Fire(self: Signal, ...)
  -- Enqueue fire if needed
  if (firingSignal) then
    enqueue(coroutine.running())
  end

  firingSignal = self
  local link = self._tail
  while (link) do
    if (link.Connected) then
      local thread = getThread()
      task.spawn(thread, link._func, thread, ...)
    end
    link = link._prev
  end

  local state = processDisconnectState(self)
  if (state ~= CANCEL_QUEUE) then
    for i = 1, #sharedQueue, 2 do
      local connection = sharedQueue[i]:: Connection
      local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()
      mutation(connection, connection._signal)
    end
  end
  table.clear(sharedQueue)
  firingSignal = nil

  local thread = dequeue(self)
  if (thread) then
    coroutine.resume(thread)
  end
end

local function SyncFire(self: Signal, ...)
  local link = self._tail
  local stopAt = self._head
  while (link) do
    -- I would use pcall, but types for it are broken
    xpcall(link._func, warn, ...)
    while (stopAt and (stopAt.Connected == false)) do
      if (self._head == nil or stopAt == link) then
        return
      end
      stopAt = stopAt._next
    end
    if (link == stopAt) then
      return
    end
    link = link._prev
  end
end

local function PriorityFire(self: Signal, ...)
  -- Enqueue fire if needed
  if (firingSignal) then
    enqueue(coroutine.running())
  end

  firingSignal = self
  local link = self._priorityTail
  while (link) do
    if (link.Connected) then
      local thread = getThread()
      task.spawn(thread, link._func, thread, ...)
    end
    link = link._priorityPrev
  end

  local state = processDisconnectState(self)
  if (state ~= CANCEL_QUEUE) then
    for i = 1, #sharedQueue, 2 do
      local connection = sharedQueue[i]:: Connection
      local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()
      mutation(connection, connection._signal)
    end
  end
  table.clear(sharedQueue)
  firingSignal = nil

  local thread = dequeue(self)
  if (thread) then
    coroutine.resume(thread)
  end
end

local function SyncPriorityFire(self: Signal, ...)
  local link = self._priorityTail
  local stopAt = self._priorityHead
  while (link) do
    xpcall(link._func, warn, ...)
    while (stopAt and (stopAt.Connected == false)) do
      if (self._head == nil or stopAt == link) then
        return
      end
      stopAt = stopAt._priorityNext
    end
    if (link == stopAt) then
      return
    end
    link = link._priorityPrev
  end
end

-- if signal is firing then it's default behavior is default which defer disconnect current connections and immediately disconnects nested connections
-- otherwise, it acts like DisconnectCurrentConnections
local function DisconnectAll(self: Signal, ty: ("default" | "immediate")?)
  local type = ty or "default"
  if (sharedDisconnectAllStates[firingSignal] == CANCEL_QUEUE) then
    return
  elseif (firingSignal) then
    if (type == "default") then
      local state = sharedDisconnectAllStates[self]
      if (state and state ~= DISCONNECT_CURRENT) then
        sharedDisconnectAllStates[self] = DISCONNECT_EVERYTHING
      else
        sharedDisconnectAllStates[self] = DISCONNECT_CURRENT
      end
    else
      helperDisconnectCurrentConnections(self)
    end
    local len = #sharedQueue
    local transfer = table.create(len):: {Connection | (self: Connection, signal: Signal) -> ()}
    for i = 1, len, 2 do
      local connection = sharedQueue[i]:: Connection
      local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()

      if (mutation == onNewConnection and connection._signal == self) then
        connection.Connected = false
      elseif (connection.Connected or (mutation == helperChangePriority and not connection._isInCreationQueue)) then
        -- im passing over helperChangePriority later down the queue because there could be a weird edge case
        table.insert(transfer, connection)
        table.insert(transfer, mutation)
      end
    end
    sharedQueue = transfer
    return
  end
  helperDisconnectCurrentConnections(self)
end

-- if signal is firing then it's default behavior is deferred, otherwise, its immediate
local function DisconnectCurrentConnections(self: Signal, ty: ("deferred" | "immediate")?)
  local type = ty or "deferred"
  if (sharedDisconnectAllStates[firingSignal] == CANCEL_QUEUE) then
    return
  elseif (firingSignal) then
    if (type == "immediate") then
      helperDisconnectCurrentConnections(self)
      return
    else
      local state = sharedDisconnectAllStates[self]
      if (state and state ~= DISCONNECT_CURRENT) then
        sharedDisconnectAllStates[self] = DISCONNECT_EVERYTHING
      else
        sharedDisconnectAllStates[self] = DISCONNECT_CURRENT
      end
      return
    end
  end
  helperDisconnectCurrentConnections(self)
end

-- if signal is firing then it's default behavior is immediate, otherwise, it does nothing
local function DisconnectNestedConnections(self: Signal, ty: ("deferred" | "immediate" | "both")?)
  local type = ty or "immediate"
  if (sharedDisconnectAllStates[firingSignal] == CANCEL_QUEUE) then
    return
  elseif (firingSignal) then
    local state = sharedDisconnectAllStates[self]
    if (type == "deferred" or type == "both") then
      if (state and state ~= DISCONNECT_NESTED) then
        sharedDisconnectAllStates[self] = DISCONNECT_EVERYTHING
      else
        sharedDisconnectAllStates[self] = DISCONNECT_NESTED
      end
      if (type == "deferred") then
        return
      end
    end
  end
  local len = #sharedQueue
  local transfer = table.create(len):: {Connection | (self: Connection, signal: Signal) -> ()}
  for i = 1, len, 2 do
    local connection = sharedQueue[i]:: Connection
    local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()

    if (mutation == onNewConnection and connection._signal == self) then
      connection.Connected = false
    elseif (connection.Connected or (mutation == helperChangePriority and not connection._isInCreationQueue)) then
      -- im passing over helperChangePriority later down the queue because there could be a weird edge case
      table.insert(transfer, connection)
      table.insert(transfer, mutation)
    end
  end
  sharedQueue = transfer
end

-- if signal is firing then it's default behavior is deferred, otherwise, it does nothing
local function CancelAllMutations(self: Signal, ty: ("deferred" | "immediate" | "both")?)
  local type = ty or "deferred"
  if (firingSignal) then
    if (type == "immediate" or type == "both") then
      table.clear(sharedDisconnectAllStates)
      for i = 1, #sharedQueue, 2 do
        local connection = sharedQueue[i]:: Connection
        local mutation = sharedQueue[i + 1]:: (self: Connection, signal: Signal) -> ()
        connection._deferredPriority = nil
        if (mutation == onNewConnection) then
          connection.Connected = false
        end
      end
      table.clear(sharedQueue)
    end 
    if (type == "deferred" or type == "both") then
      sharedDisconnectAllStates[firingSignal] = CANCEL_QUEUE
    end
  end
end

-- Creates a new signal object
local function newSignal(): Signal<...any>
  return {
    Connect = Connect,
    Once = Once,
    Wait = Wait,
    DisconnectAll = DisconnectAll,
    DisconnectCurrentConnections = DisconnectCurrentConnections,
    DisconnectNestedConnections = DisconnectNestedConnections,
    CancelAllMutations = CancelAllMutations,
    Fire = Fire,
    SyncFire = SyncFire,
    PriorityFire = PriorityFire,
    SyncPriorityFire = SyncPriorityFire
  }
end

return {
  new = newSignal
}