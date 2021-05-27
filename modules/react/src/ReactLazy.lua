-- upstream: https://github.com/facebook/react/blob/v17.0.2/packages/react/src/ReactLazy.js
--[[
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
 *]]

local Workspace = script.Parent.Parent
-- ROBLOX: use patched console from shared
local console = require(Workspace.Shared.console)
local ReactTypesModule = require(Workspace.Shared.ReactTypes)
type Wakeable = ReactTypesModule.Wakeable
type Thenable<R> = ReactTypesModule.Thenable<R, any>
local ReactSymbolsModule = require(Workspace.Shared.ReactSymbols)

local REACT_LAZY_TYPE = ReactSymbolsModule.REACT_LAZY_TYPE

local Uninitialized = -1
local Pending = 0
local Resolved = 1
local Rejected = 2

type UninitializedPayload<T> = {
	-- ROBLOX deviaton: Luau doesn't support literals
	--   _status: -1,
	_status: number,
	_result: () -> Thenable<{ default: T, [any]: any }>,
}

type PendingPayload = {
	-- ROBLOX deviaton: Luau doesn't support literals
	-- _status: 0,
	_status: number,
	_result: Wakeable,
}

type ResolvedPayload<T> = {
	-- ROBLOX deviaton: Luau doesn't support literals
	-- _status: 1,
	_status: number,
	_result: T,
}

type RejectedPayload = {
	-- ROBLOX deviaton: Luau doesn't support literals
	-- _status: 2,
	_status: number,
	_result: any,
}

type Payload<T> = UninitializedPayload<T> | PendingPayload | ResolvedPayload<T> | RejectedPayload

export type LazyComponent<T, P> = any -- {
-- ROBLOX FIXME: Luau can't express type keys with special chars
--     -- $$typeof: Symbol | number,
--   _payload: P,
--   _init: (P) -> T,
--   ...
-- }

-- ROBLOX TODO: function generics
-- function lazyInitializer<T>(payload: Payload<T>): T {
function lazyInitializer(payload: Payload<any>): any
	if payload._status == Uninitialized then
		local ctor = payload._result
		local thenable = ctor()
		-- Transition to the next state.
		-- ROBLOX TODO: workaround Luau false positive, removed : PendingPayload
		local pending = payload
		pending._status = Pending
		pending._result = thenable
		thenable:andThen(function(moduleObject)
			if payload._status == Pending then
				local defaultExport = moduleObject.default
				if _G.__DEV__ then
					if defaultExport == nil then
						console.error(
							"lazy: Expected the result of a dynamic import() call. " ..
								"Instead received: %s\n\nYour code should look like: \n  " ..
								-- Break up imports to avoid accidentally parsing them as dependencies.
							    -- ROBLOX deviation: Lua syntax in message
                                "local MyComponent = lazy(function() => req" ..
								"quire('script.Parent.MyComponent') end)",
							moduleObject
						)
					end
				end
				-- Transition to the next state.
				local resolved: ResolvedPayload<any> = payload
				resolved._status = Resolved
				resolved._result = defaultExport
			end
		end, function(error_)
			if payload._status == Pending then
				-- Transition to the next state.
				local rejected: RejectedPayload = payload
				rejected._status = Rejected
				rejected._result = error_
			end
		end)
	end
	if payload._status == Resolved then
		return payload._result
	else
		error(payload._result)
	end
end

local exports = {}

-- ROBLOX TODO: function generics
-- function lazy<T>(
--     ctor: () => Thenable<{default: T, ...}>,
-- ): LazyComponent<T, Payload<T>> {
exports.lazy = function(
	ctor: () -> Thenable<{ default: any }> -- ROBLOX TODO: Luau can't express: , ...}>,
): LazyComponent<any, Payload<any>>
	local payload: Payload<any> = {
		-- We use these fields to store the result.
		_status = -1,
		_result = ctor,
	}

	local lazyType: LazyComponent<any, Payload<any>> = {
		["$$typeof"] = REACT_LAZY_TYPE,
		_payload = payload,
		_init = lazyInitializer,
	}

	if _G.__DEV__ then
	    -- In production, this would just set it on the object.
	    local defaultProps
	    local propTypes
	    -- $FlowFixMe
		setmetatable(lazyType, {
			__index = function(self, key)
		        if key == "defaultProps" then
					return defaultProps
				end
		        if key == "propTypes" then
					return propTypes
				end
				return
			end,
			__newindex = function(self, key, value)
		        if key == "defaultProps" then
					console.error(
						'React.lazy(...): It is not supported to assign `defaultProps` to ' ..
						  'a lazy component import. Either specify them where the component ' ..
						  'is defined, or create a wrapping component around it.'
					  )
					  defaultProps = value
					-- Match production behavior more closely:
					-- $FlowFixMe
					setmetatable(self, {
						__index = function() end,
						__newindex = function() end
					})
				end
		        if key == "propTypes" then
					console.error(
					'React.lazy(...): It is not supported to assign `propTypes` to ' ..
						'a lazy component import. Either specify them where the component ' ..
						'is defined, or create a wrapping component around it.'
					)
					propTypes = value
					-- Match production behavior more closely:
					-- $FlowFixMe
					setmetatable(self, {
						__index = function() end,
						__newindex = function() end
					})
				end
			end
		})
	end

	return lazyType
end

return exports
