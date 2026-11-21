-- PRIME  PRIME: refreshed interface and premium popup suite.
-- Radar signal mapping is fixed: healthy=green, damaged=yellow, critical=red, bots=blue, vehicles=violet.
-- Retained suite: Name, Line, Box, Health, Distance, Skeleton, Counter, Radar, iPad View, Aim V1.
-- Vehicle radar note: actor registration bridge is present; automatic vehicle discovery is game-API dependent.
-- Radar range, actor tracking, marker projection, ESP toggles and gameplay hooks retained.
-- Native settings revision, welcome only, Hack menu last (2026-10-08)
-- Fresh camera projections; retained feature switches, range and render limits.
-- Actor-free widget pools flush on canvas/world reset; optional total callback profiling.
-- Title: New hud based smooth ESP by @UXOfficial
-- BRPlayerCharacterBase NEW ESP made by @UXOfficial

_G.g_UXOfficial = _G.g_UXOfficial or "@PRIME"
local g_UXOfficial_credit = _G.g_UXOfficial
_G.g_UXOfficial_VisualEdition = "PRIME  PRIME"

local g_UXOfficial_StartSettingsMaintenance

-- ============================================================================
-- ORIGINAL GAME CODE START | BRPlayerCharacterBase
-- Native RPCs, imports, lifecycle, movement, parachute, vehicle and emote logic.
-- The supplied original game code below is preserved verbatim.
-- ============================================================================
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ECharacterHideMovementAcive = import("ECharacterHideMovementAcive")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

-- ============================================================================
-- VIPGROUP  OFFLINE EXPIRY ACCESS (no panel, key input, or HTTP verification)
-- Expiry configuration + original welcome popup are below.
-- Compatibility adapter: the existing Skin/Wall/ESP checks use LicenseValid.
-- ============================================================================
_G.LicenseValid = false
local _FAHADLastExpiryCheckSecond = nil
function _G.AHMADAuthActive()
    local now = os.time()
    if now ~= _FAHADLastExpiryCheckSecond then
        _FAHADLastExpiryCheckSecond = now
        if type(CheckExpiration) == "function" then
            return CheckExpiration()
        end
    end
    return _G.LicenseValid == true
end





function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
    self:AddControlEvent(self, "OnPawnRespawnDelegate", self.OnRespawnRehideCheck, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if _G.FAHADQuickGiveUpEnabled == true and
      (PawnState == EPawnState.NearDeath or PawnState == EPawnState.Dying) then
    pcall(function() self:CheckAndEnableGiveUp() end)
  end
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:OnRespawnRehideCheck()
  if not self:GetEnsure() then
    return
  end
  self:AddGameTimer(0.5, false, function()
    if not slua.isValid(self.Object) then
      return
    end
    if self:HasState(EPawnState.InPlane) then
      self:SetCharacterHideInGame(true, true, true, 1, ECharacterHideMovementAcive.Normal)
      print(bWriteLog and "BRPlayerCharacterBase:OnRespawnRehideCheck re-hide AI on plane, PlayerKey:", self.PlayerKey)
    end
  end)
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")

  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end

  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local VICTORY_DANCE_FX_MAP = {
  [12219601] = 22010089
}
local PublishRegionMacros = require("client.slua.config.ClientMacros.PublishRegionMacros")
local isFitVersion = PublishRegionMacros.IsFITVersion()

local function ResolveEmoteResID(ItemID)
  local FxID = VICTORY_DANCE_FX_MAP[ItemID]
  if not FxID or FxID == ItemID then
    return ItemID
  end
  local model_util = require("client.common.model_util")
  local FxBPID = model_util.GetBPID(FxID)
  local ResID = ItemID
  if FxBPID and 0 < FxBPID and model_util.IsBattleItemHandleExist("Emote", FxBPID, false, false) then
    ResID = FxID
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase 11 ResolveEmoteResID ItemID:%s, FxID:%s, FxBPID:%s, ResID:%s", tostring(ItemID), tostring(FxID), tostring(FxBPID), tostring(ResID)))
  if isFitVersion and ResID == 12219601 then
    print(bWriteLog and "BRPlayerCharacterBase ResolveEmoteResID 12219601 to 12222069")
    return 12222069
  end
  return ResID
end

function BRPlayerCharacterBase:GetEmoteHandlePath(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandlePath(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return ""
  end
  return model_util.GetPath("Emote", BPID, false, false) or ""
end

function BRPlayerCharacterBase:GetEmoteHandle(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandle(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return nil
  end
  local HandleClass = model_util.GetClass("Emote", BPID, false, false)
  if not HandleClass then
    return nil
  end
  local Handle = HandleClass()
  if not slua.isValid(Handle) then
    return nil
  end
  return Handle
end

-- ORIGINAL GAME CODE END | BRPlayerCharacterBase

-- ============================================================================
-- ============================================================================
-- BYPASS START
-- ============================================================================
-- ============================================================================
-- ESP reporting and detection hooks
-- Source: BRPlayerCharacterBase.lua (118 KB script) — Bypass.lua integrated
-- Auto-runs on pawn spawn and respawn.
-- Wrapped with BYPASS START / BYPASS END markers for later separation.
-- ============================================================================

do -- V9.5 integration: scope helper locals below the Lua chunk limit.
local function _BYPASS_InstallESPHandlers()
    if _G.__UXOfficial_ESP_BYPASS_LOADED then return end

    local nop = function() end

    local function isBypassActive()
        return _G._ESP_BYPASS_ACTIVE == true
    end

    -- Non-wall ESP/reporting hooks retained from the supplied integration.
    ---------- LAYER 8: Kernel & memory spoof ----------
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then return origIKC(self) end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then return origGKV(self) end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
            end
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then return origIMC(self) end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then return origSR(self) end
                    return "clean"
                end
                mg.__akhooked = true
            end
        end
    end)

    ---------- LAYER 9: MARK SYSTEM SPOOF ----------
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            local ourMarkGroups = {1006, 9999}
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks or type(marks) ~= "table" then return marks end
                    local filtered = {}
                    for _, m in ipairs(marks) do
                        if m.MarkGroupID and not table.contains(ourMarkGroups, m.MarkGroupID) then
                            table.insert(filtered, m)
                        end
                    end
                    return filtered
                end
            end
            if MarkMgr.GetMarkCount then
                local orig = MarkMgr.GetMarkCount
                MarkMgr.GetMarkCount = function(self, ...)
                    local count = orig(self, ...)
                    if isBypassActive() then count = math.max(0, count - 2) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and (groupId == 1006 or groupId == 9999) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    ---------- LAYER 10: REPLAY UI DETECTION KILL ----------
    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted then
            local orig = _G.Replay_IsEnemyFrameUIExisted
            _G.Replay_IsEnemyFrameUIExisted = function(...)
                if isBypassActive() then return false end
                return orig(...)
            end
        end
        if _G.Replay_CreateEnemyFrameUI then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                if isBypassActive() then
                    local backup = _G.ReportEnemyFrameUI or nop
                    _G.ReportEnemyFrameUI = nop
                    local res = orig(...)
                    _G.ReportEnemyFrameUI = backup
                    return res
                end
                return orig(...)
            end
        end
    end)

    ---------- LAYER 13: ESP-RELATED REPORT FUNCTIONS KILL ----------
    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "SendESPData","UploadESPInfo"
        }
        for _, fn in ipairs(espReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    ---------- LAYER 14: NETWORK ESP PACKET BLOCK ----------
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and tostring(pname):lower():match("esp") then return nil end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName and tostring(rpcName):lower():match("esp") then return end
                return orig(rpcName, ...)
            end
        end
    end)

    _G.__UXOfficial_ESP_BYPASS_LOADED = true
    print("[ok] ESP reporting handlers installed")
end

-- ========================================================================
-- ESP REPORT HANDLERS + DETECTION SUBSYSTEM HOOKS
-- ========================================================================
local function _BYPASS_SetupESPBypassTable()
    local bypass = {}
    local function nop() end
    local function returnTrue() return true end
    local function returnFalse() return false end
    local function safe_require(mod)
        local ok, res = pcall(require, mod)
        return ok and res or nil
    end
    local function tryImport(name)
        local ok, lib = pcall(import, name)
        return ok and lib or nil
    end

    local function blockScreenshots()
        pcall(function()
            local SS = tryImport("ScreenshotMaker") or tryImport("ScreenshotMTDer")
            if SS then
                SS.MakePicture = function() return "" end
                SS.ReMakePicture = function() return "" end
                SS.HasCaptured = returnTrue
            end
        end)
    end

    local function blockGameplayCallbacks()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC._ESPReportHooksApplied then return end

        local reportFuncs = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
            "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
            "ReportAimbot","ReportSpeedHack","ReportMagicBullet",
            "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
            "ReportMaterialScan","ReportShaderOverride","ReportCircleFlow",
            "OnPlayerRPCValidateFailed","OnPlayerActorChannelError",
            "OnPlayerSpectateException","OnShutdownAfterError"
        }
        for _, fn in ipairs(reportFuncs) do GC[fn] = nop end

        local oldStateChanged = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, state, ...)
            if state and type(state) == "string" then
                local s = state:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity") then return end
            end
            if oldStateChanged then return oldStateChanged(UID, state, ...) end
        end

        GC._ESPReportHooksApplied = true
    end

    local function spoofTssSdk()
        pcall(function()
            local t = _G.TssSdk
            if t then
                t.GetFileMD5 = function() return "" end
                t.VerifyFileSignature = returnTrue
                t.CheckIntegrity = returnTrue
                t.ScanMemory = function() return true, {} end
                t.IsEmulator = returnFalse
                t.OnRecvData = nop
            end
        end)
    end

    local function disableDetectionSubsystems()
        local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not sm then return end

        local targetSubs = {
            "ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem", "ShootVerifySubSystemClient",
            "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
            "ClientKernelCheckSubsystem", "ClientHawkEyePatrolSubsystem",
            "ClientAntiCheatSubsystem", "IntegrityCheckSubsystem",
            "FileCheckSubsystem", "AvatarExceptionSubsystem"
        }
        for _, sn in ipairs(targetSubs) do
            local sub = sm:Get(sn)
            if sub and type(sub) == "table" then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        if k:find("Report") or k:find("Send") or k:find("Verify") or
                           k:find("Check") or k:find("Detect") or k:find("Scan") then
                            sub[k] = nop
                        end
                    end
                end

                if sn == "ClientESPDetectionSubsystem" then                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = returnFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math.random(45,65), headshotRate = math.random(15,35) }
                    end
                    sub.IsAimNormal = returnTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = nop
                    sub.VerifyShot = returnTrue
                end
            end
        end
    end

    local function disableHiggsBoson()
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc then
                hbc.bMHActive = false
                hbc.bCallPreReplication = false
                if hbc.ControlMHActive then hbc.ControlMHActive = nop end
                if hbc.StartAvatarCheck then hbc.StartAvatarCheck = nop end
                if hbc.BlackList then
                    for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
                end
            end
            if _G.AvatarCheckCallback then
                _G.AvatarCheckCallback.StartAvatarCheck = nop
                _G.AvatarCheckCallback.OnReportItemID = nop
            end
            _G.BlackList = {}
        end)
    end

    function bypass.Init()
        blockScreenshots()
        blockGameplayCallbacks()
        spoofTssSdk()
        disableDetectionSubsystems()
        disableHiggsBoson()
    end

    _G.ESPBypass = bypass
end

-- ========================================================================
-- BYPASS EXECUTION
-- ========================================================================
local function _BYPASS_Execute()
    if _G._BYPASS_DONE then return end
    local ok, err = pcall(function()
        _G._ESP_BYPASS_ACTIVE = true
        _BYPASS_InstallESPHandlers()
        _BYPASS_SetupESPBypassTable()
        if _G.ESPBypass and _G.ESPBypass.Init then
            _G.ESPBypass.Init()
        end
        _G._BYPASS_DONE = true
        print("[ORDER] All bypasses executed")
    end)
    if not ok then
        print("[ORDER] Bypass failed, will retry:", tostring(err))
        _G._BYPASS_DONE = false
    end
end

-- Expose globally so callback bridge / any other scope can trigger it.
_G._BYPASS_Execute = _BYPASS_Execute
end -- V9.5 integration: exported callback retains the scoped helpers.

-- ============================================================================
-- ============================================================================
-- BYPASS END
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE | tracking and settings maintenance
-- Each adapter runs the original game callback once, then its existing addition.
-- ============================================================================
do
    local additions={
        ReceiveBeginPlay=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            if g_UXOfficial_StartSettingsMaintenance then pcall(g_UXOfficial_StartSettingsMaintenance,self) end
            -- AUTO BYPASS TRIGGER: runs on pawn spawn.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
        ReceiveEndPlay=function(self)
            if _G.g_UXOfficial_TrackedCharacters and self.Object then
                _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=nil
            end
        end,
        BPOnRespawned=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            -- AUTO BYPASS TRIGGER on respawn as well.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
        ReceiveOnRecycle=function(self)
            if _G.g_UXOfficial_TrackedCharacters and self.Object then
                _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=nil
            end
        end,
        ReceiveOnSpawn=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            -- AUTO BYPASS TRIGGER on spawn.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
    }
    for name,addition in pairs(additions) do
        local originalCallback=BRPlayerCharacterBase[name]
        local afterCallback=addition
        BRPlayerCharacterBase[name]=function(self,...)
            originalCallback(self,...)
            if Client then afterCallback(self) end
        end
    end
end
-- MAIN SCRIPT CALLBACK BRIDGE END

-- Immediate bypass attempt on script load (in case a pawn is already present).
if Client and _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end

_G.LexusConfig = _G.LexusConfig or {}
_G.LexusConfig.IpadView = _G.LexusConfig.IpadView or false
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
_G.LexusState.CustomTextData.IpadViewFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120
-- [VIPGROUP  MERGE] Skin-only config taken from the original 1.lua feature flags.
_G.LexusConfig = _G.LexusConfig or {}
if _G.LexusConfig.ModEmote == nil then _G.LexusConfig.ModEmote = false end
if _G.LexusConfig.SkinOpenLink == nil then _G.LexusConfig.SkinOpenLink = false end
if _G.LexusConfig.ModSkin == nil then _G.LexusConfig.ModSkin = false end
if _G.LexusConfig.SkinDeadBox == nil then _G.LexusConfig.SkinDeadBox = false end
if _G.LexusConfig.SkinAttachment == nil then _G.LexusConfig.SkinAttachment = false end
if _G.LexusConfig.KillMessage == nil then _G.LexusConfig.KillMessage = false end
if _G.LexusConfig.KillCountUI == nil then _G.LexusConfig.KillCountUI = false end
if _G.LexusConfig.SkinOptionOpen == nil then _G.LexusConfig.SkinOptionOpen = false end
if _G.LexusConfig.SkinEnable_Suit == nil then _G.LexusConfig.SkinEnable_Suit = false end
if _G.LexusConfig.SkinEnable_Top == nil then _G.LexusConfig.SkinEnable_Top = false end
if _G.LexusConfig.SkinEnable_Gloves == nil then _G.LexusConfig.SkinEnable_Gloves = false end
if _G.LexusConfig.SkinEnable_Bottom == nil then _G.LexusConfig.SkinEnable_Bottom = false end
if _G.LexusConfig.SkinEnable_Shoes == nil then _G.LexusConfig.SkinEnable_Shoes = false end
if _G.LexusConfig.SkinEnable_Bag == nil then _G.LexusConfig.SkinEnable_Bag = false end
if _G.LexusConfig.SkinEnable_Helmet == nil then _G.LexusConfig.SkinEnable_Helmet = false end
if _G.LexusConfig.SkinEnable_Parachute == nil then _G.LexusConfig.SkinEnable_Parachute = false end
if _G.LexusConfig.SkinEnable_M416 == nil then _G.LexusConfig.SkinEnable_M416 = false end
if _G.LexusConfig.SkinEnable_AKM == nil then _G.LexusConfig.SkinEnable_AKM = false end
if _G.LexusConfig.SkinEnable_SCAR == nil then _G.LexusConfig.SkinEnable_SCAR = false end
if _G.LexusConfig.SkinEnable_M762 == nil then _G.LexusConfig.SkinEnable_M762 = false end
if _G.LexusConfig.SkinEnable_AUG == nil then _G.LexusConfig.SkinEnable_AUG = false end
if _G.LexusConfig.SkinEnable_UMP == nil then _G.LexusConfig.SkinEnable_UMP = false end
if _G.LexusConfig.SkinEnable_UZI == nil then _G.LexusConfig.SkinEnable_UZI = false end
if _G.LexusConfig.SkinEnable_Groza == nil then _G.LexusConfig.SkinEnable_Groza = false end
if _G.LexusConfig.SkinEnable_S12K == nil then _G.LexusConfig.SkinEnable_S12K = false end
if _G.LexusConfig.SkinEnable_DBS == nil then _G.LexusConfig.SkinEnable_DBS = false end
if _G.LexusConfig.SkinEnable_Dacia == nil then _G.LexusConfig.SkinEnable_Dacia = false end
if _G.LexusConfig.SkinEnable_UAZ == nil then _G.LexusConfig.SkinEnable_UAZ = false end
if _G.LexusConfig.SkinEnable_Coupe == nil then _G.LexusConfig.SkinEnable_Coupe = false end
if _G.LexusConfig.SkinEnable_Buggy == nil then _G.LexusConfig.SkinEnable_Buggy = false end
if _G.LexusConfig.SkinEnable_Mirado == nil then _G.LexusConfig.SkinEnable_Mirado = false end
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}


-- g_UXOfficial_GetLocalPlayer made by @UXOfficial
local function g_UXOfficial_GetLocalPlayer()
    local ok, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GDP then return nil end
    local player = GDP.GetPlayerCharacter()
    if player and slua.isValid(player) then return player end
    return nil
end

-- g_UXOfficial_ApplyiPadView made by @UXOfficial
local function g_UXOfficial_ApplyiPadView()
    local player = g_UXOfficial_GetLocalPlayer()
    if not player then return end
    local cam = player.ThirdPersonCameraComponent
    if not cam or not slua.isValid(cam) then return end
    if player.bIsWeaponAiming then return end

    if _G.LexusConfig.IpadView then
        local targetFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120
        if cam.FieldOfView ~= targetFOV then
            cam.FieldOfView = targetFOV
        end
    else
        if cam.FieldOfView ~= 90 then
            cam.FieldOfView = 90
        end
    end
end

-- Persistent ESP feature settings.
local g_UXOfficial_ESPOptionDefaults = {
    Name=false, Line=false, Box=false, Health=false, Distance=false, Skeleton=false, Counter=false, Radar=false
}
_G.g_UXOfficial_ESPOptions = _G.g_UXOfficial_ESPOptions or {}
for k,v in pairs(g_UXOfficial_ESPOptionDefaults) do
    if _G.g_UXOfficial_ESPOptions[k] == nil then _G.g_UXOfficial_ESPOptions[k] = v end
end
local g_UXOfficial_ESPSettingsFile = "UXOfficial_UMG_ESP_settings.lua"
local function g_UXOfficial_ESPSettingsPaths()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        g_UXOfficial_ESPSettingsFile
    }
    local home=nil
    pcall(function() if os and os.getenv then home=os.getenv("HOME") end end)
    if type(home)=="string" and home~="" then
        table.insert(paths,1,home.."/Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile)
    end
    return paths
end
-- Replace the SaveGames file only after write/flush/close succeed where Lua
-- exposes rename. A failed temporary write keeps the last saved file intact.
local function g_UXOfficial_ESPWriteSettings(path,payload)
    local atomic=os and type(os.rename)=="function"
    local target=atomic and path..".tmp" or path
    local opened,file=pcall(io.open,target,"w")
    if not opened or not file then return false,"Open failed: "..target end
    local closed=false
    local ok,err=pcall(function()
        local result,reason=file:write(payload)
        assert(result,reason or "Settings write failed")
        if file.flush then local flushed,why=file:flush();assert(flushed,why or "Settings flush failed") end
        local result,reason=file:close();closed=true
        assert(result,reason or "Settings close failed")
    end)
    if not closed then pcall(function() file:close() end) end
    if ok and atomic then
        local called,result,reason=pcall(os.rename,target,path)
        ok=called and result~=nil and result~=false
        err=ok and nil or (reason or result or "Settings rename failed")
    end
    if not ok and atomic and os.remove then pcall(os.remove,target) end
    return ok,err,atomic
end

local g_UXOfficial_ESPLoadedSettingsPath=nil

local function g_UXOfficial_ESPLoadSettings()
    if not io or type(io.open) ~= "function" then return false end
    local paths = g_UXOfficial_ESPSettingsPaths()
    local content=nil
    for _,path in ipairs(paths) do
        local ok,f=pcall(io.open,path,"r")
        if ok and f then
            local rok,text=pcall(function() return f:read("*a") end)
            pcall(function() f:close() end)
            if rok and type(text)=="string" and text~="" then content=text;g_UXOfficial_ESPLoadedSettingsPath=path;break end
        end
    end
    if not content then return false end
    for k in pairs(g_UXOfficial_ESPOptionDefaults) do
        local v=content:match(k.."%s*=%s*(true)") or content:match(k.."%s*=%s*(false)")
        if v then _G.g_UXOfficial_ESPOptions[k]=(v=="true") end
    end
    return true
end
g_UXOfficial_ESPLoadSettings()

-- Settings registration follows the supplied working native-page reference.
-- Feature rows and option values remain owned by this script.
local g_UXOfficial_EnsureHackMenu
do
    local VERSION = "LunarSettings.V9.6.LastPage.NoV1NoWall"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        -- A live page already occupying the last slot needs no mutation.
        if catalog[#catalog] == page then
            local duplicate = false
            for i = 1, #catalog - 1 do
                if type(catalog[i]) == "table" and catalog[i].Key == "HackMenu" then
                    duplicate = true
                    break
                end
            end
            if not duplicate then return true end
        end
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "HackMenu" then
                table.remove(catalog, i)
            end
        end
        catalog[#catalog+1] = page
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__LunarSettingsUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    -- Unwrap our previous version instead of nesting its older
                    -- ShowUI handler, which could reinsert this tab at the top.
                    local baseShow = show
                    if type(record) == "table" and record.Wrapper == show and
                        type(record.Original) == "function" then
                        baseShow = record.Original
                    end
                    record = {Version = VERSION, Original = baseShow}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        -- Register again before opening, including rebuilt mode catalogs.
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__LunarSettingsUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function restoreAliases(state, aliases)
        for _, manager in ipairs(state.Managers or {}) do
            local config = member(manager, "UI_Config")
            if config then
                for _, key in ipairs({"Switcher", "Slider"}) do
                    if type(aliases[key]) ~= "table" then
                        local value = member(config, "Setting_Option_" .. key)
                        if type(value) == "table" then aliases[key] = value end
                    end
                end
            end
        end
    end
    local function syncModeCatalogs(state)
        local names = {"GameLua.Mod.BaseMod.Client.Config.SettingCatalog",
            "GameLua.Mod.D350.Client.Config.SettingCatalog",
            "GameLua.Mod.PlanPH.Client.Config.SettingCatalog"}
        for i, name in ipairs(names) do
            local catalog = package and package.loaded and package.loaded[name]
            if type(catalog) ~= "table" and i == 1 then
                local ok, value = pcall(loadTable, name)
                if ok then catalog = value; state.ModeCatalogError = nil
                else state.ModeCatalogError = tostring(value) end
            end
            if type(catalog) == "table" then register(catalog, state.Page) end
        end
    end
    local function buildPage(F, AliasMap, sliderReady)
    local function featureState() return _G.LunarFeatures end
    local function value(c,v) if v==nil then return c end return v end
    local function espAll()
        return {Key="LunarV2_All",UI=AliasMap.Switcher,Text="All ESP",
            LunarBulk=true,
            SwitcherText={"All On","All Off"},
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return featureState().GetESPAll(2) end,
            SetFunc=function(c,v) return featureState().SetESPAll(2,value(c,v)) end}
    end
    local function espSwitch(key,label)
        return {Key="UXOfficialESP_"..key,
            UI=AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return _G.g_UXOfficial_ESPOptions[key]==true end,
            SetFunc=function(c,v) return featureState().SetESP(2,key,value(c,v)) end}
    end
    local V2={espAll(),
        espSwitch("Name","ESP NAME"),espSwitch("Line","ESP LINE"),espSwitch("Box","ESP BOX"),
        espSwitch("Health","ESP HEALTH"),espSwitch("Distance","ESP DISTANCE"),
        espSwitch("Skeleton","ESP SKELETON"),espSwitch("Counter","ESP COUNTER"),espSwitch("Radar","RADAR MAP")}
    local Other={
        {Key="LunarIpad",UI=AliasMap.Switcher,Text="iPad View",ExpandIndex=0,
            GetFunc=function() return _G.LexusConfig.IpadView end,
            SetFunc=function(c,v) featureState().SetIpad(value(c,v));return true end},
        {Key="LunarAim",UI=AliasMap.Switcher,Text="Aimbot V1",ExpandIndex=0,
            EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
            GetFunc=function() return featureState().Settings.AimEnabled end,
            SetFunc=function(c,v) featureState().SetAim(value(c,v));return true end}
    }
    -- Verified native settings item contract: absolute Min/Max values, native
    -- key/value callbacks, and expansion events owned by the game's page.
    local function rangeItem(key,label,lo,hi,parent,get,set)
        return {Key=key,UI=AliasMap.Slider,Text=label,Min=lo,Max=hi,ExpandHandle=parent,
            GetFunc=function() return get() end,
            SetFunc=function(c,v)
                featureState()[set](value(c,v))
                featureState().Save(true)
                return true
            end}
    end
    if sliderReady then
        table.insert(Other,2,rangeItem("LunarIpadFOV","iPad FOV",90,120,"LunarIpad",
            function() return featureState().Settings.IpadFOV end,"SetIpadFOV"))
    end
    if sliderReady then
        Other[#Other+1]=rangeItem("LunarAimSpeed","Aim speed",100,120,"LunarAim",
            function() return featureState().Settings.AimSpeed end,"SetAimSpeed")
    end
    Other[#Other+1]={Key="LunarAimTarget",UI=AliasMap.Switcher,Text="Aim target",ExpandHandle="LunarAim",
        SwitcherText={"Head","Body","Leg"},SwitcherValue={1,2,3},
        GetFunc=function() return featureState().Settings.AimTarget end,
        SetFunc=function(c,v) featureState().SetAimTarget(value(c,v));return true end}
    Other[#Other+1]={Key="LunarAim2",UI=AliasMap.Switcher,Text="Aimbot V2",
        EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
        GetFunc=function() return featureState().Settings.Aim2Enabled end,
        SetFunc=function(c,v) featureState().SetAim2(value(c,v));return true end}
    Other[#Other+1]={Key="LunarMortarAim",UI=AliasMap.Switcher,Text="Mortar aim",
        GetFunc=function() return featureState().Settings.MortarEnabled end,
        SetFunc=function(c,v) featureState().SetMortar(value(c,v));return true end}
    local CharacterTools={
        {Key="FAHADQuickGiveUp",UI=AliasMap.Switcher,Text="Quick Give-Up",
            GetFunc=function() return _G.FAHADQuickGiveUpEnabled==true end,
            SetFunc=function(c,v) _G.FAHADQuickGiveUpEnabled=(value(c,v)==true or value(c,v)==1);return true end}
    }

    local SkinStack={
        {Key="FAHADModEmote",UI=AliasMap.Switcher,Text="Unlock All VIP Emotes",
         GetFunc=function() return _G.LexusConfig.ModEmote==true end,
         SetFunc=function(c,v) _G.LexusConfig.ModEmote=(v==true or v==1);return true end},
        {Key="FAHADOriginalSkin",UI=AliasMap.Switcher,Text="VIP SKINS (Open inventory)",
         GetFunc=function() return _G.LexusConfig.ModSkin==true end,
         SetFunc=function(c,v)
            if _G.LicenseValid~=true then return false end
            _G.LexusConfig.ModSkin=(v==true or v==1)
            if _G.LexusConfig.ModSkin then
              pcall(function() if _G.AddOutfit and _G.AddOutfit.start then _G.AddOutfit.start() end end)
            end
            return true
         end},
        {Key="FAHADSkinDeadBox",UI=AliasMap.Switcher,Text="Deadbox Skin",
         GetFunc=function() return _G.LexusConfig.SkinDeadBox==true end,
         SetFunc=function(c,v) _G.LexusConfig.SkinDeadBox=(v==true or v==1);return true end},
        {Key="FAHADSkinAttachment",UI=AliasMap.Switcher,Text="Weapon Attachment Skins",
         GetFunc=function() return _G.LexusConfig.SkinAttachment==true end,
         SetFunc=function(c,v) _G.LexusConfig.SkinAttachment=(v==true or v==1);return true end},
        {Key="FAHADKillMessage",UI=AliasMap.Switcher,Text="VIP Kill Messenger",
         GetFunc=function() return _G.LexusConfig.KillMessage==true end,
         SetFunc=function(c,v) _G.LexusConfig.KillMessage=(v==true or v==1);return true end},
        {Key="FAHADKillCount",UI=AliasMap.Switcher,Text="Kill Counter UI",
         GetFunc=function() return _G.LexusConfig.KillCountUI==true end,
         SetFunc=function(c,v) _G.LexusConfig.KillCountUI=(v==true or v==1);return true end},
        {Key="FAHADSkinGuide",UI=AliasMap.Switcher,Text="Skin Guide (Link)",
         GetFunc=function() return _G.LexusConfig.SkinOpenLink==true end,
         SetFunc=function(c,v)
           _G.LexusConfig.SkinOpenLink=(v==true or v==1)
           if _G.LexusConfig.SkinOpenLink then pcall(function()
             local Web=require("client.slua.logic.url.logic_webview_sdk")
             if Web and Web.OpenURL then Web:OpenURL("PRIME") end
           end) end
           return true
         end},
    }
    local WallStack={
        {Key="FAHADWallMain",UI=AliasMap.Switcher,Text="WALLHACK / COLOR BODY",
         GetFunc=function() return _G.LunarFeatures and _G.LunarFeatures.Settings.WallEnabled==true end,
         SetFunc=function(c,v) return _G.LunarFeatures and _G.LunarFeatures.SetWall(v) end},
    }
    local WallColors={"Pink","White","Cyan","Green","Yellow","Saffron","Red"}
    for _,entry in ipairs({{"WallVisible","Visible color"},{"WallOccluded","Behind-wall color"}}) do
        local key,label=entry[1],entry[2]
        WallStack[#WallStack+1]={Key="VIPGROUP "..key,UI=AliasMap.CompactSwitcher or AliasMap.Switcher,Text=label,
            SwitcherText=WallColors,SwitcherValue={1,2,3,4,5,6,7},
            GetFunc=function() return _G.LunarFeatures and _G.LunarFeatures.Settings[key] or 1 end,
            SetFunc=function(c,v) return _G.LunarFeatures and _G.LunarFeatures.SetWallColor(key,v or c) end}
    end
    local page={Key="HackMenu",Text="✦ PRIME GOLD ✦",UIKey="Setting_Page_Privacy",Category={
        {Key="Lunar_ESP_V2",Text="✦ ESP V2 ✦",Stack=V2},
        {Key="Lunar_Other",Text="✦ GOLD FEATURES ✦",Stack=Other},
        {Key="FAHAD_CharacterTools",Text="✦ CHARACTER TOOLS ✦",Stack=CharacterTools},
        {Key="FAHAD_Skins",Text="✦ VIP SKINS ✦",Stack=SkinStack},
        {Key="FAHAD_Wall",Text="✦ WALLHACK ✦",Stack=WallStack}
    }}

        return page
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        restoreAliases(state, aliases)
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")

        -- Missing optional sliders must not hide the entire settings tab.
        -- Rebuild with both original slider rows as soon as their UI is available.
        local sliderReady = type(aliases.Slider) == "table"
        local compact = aliases.CompactSwitcher or aliases.Switcher
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
            or state.CompactSwitcher ~= compact
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.CompactSwitcher = compact
        state.SliderReady = sliderReady
        state.DeferredSliderRows = sliderReady and 0 or 2
        pages.HackMenu = state.Page
        state.Registered = register(catalog, state.Page)
        syncModeCatalogs(state)

        -- Bulk selector enhancement is optional; its failure cannot block the page.
        local okClass, switchClass = pcall(loadTable, "client.slua.umg.NewSetting.Item.Setting_Option_Switcher")
        if okClass and type(F.InstallNativeBulkSwitch) == "function" then
            local okBulk, result = pcall(F.InstallNativeBulkSwitch, switchClass)
            state.BulkSwitchReady = okBulk and result == true
            state.BulkSwitchError = not okBulk and tostring(result) or nil
        else
            state.BulkSwitchReady = false
            state.BulkSwitchError = not okClass and tostring(switchClass) or "BULK_SWITCH_HELPER_UNAVAILABLE"
        end
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "UXOfficial_NATIVE_SETTINGS_V9_2"
        else state.LastError = "SETTINGS_UI_MANAGER_NOT_READY" end
        return state.Ready
    end
    g_UXOfficial_EnsureHackMenu = function()
        if _G.AHMADAuthActive and not _G.AHMADAuthActive() then return false end
        local state = runtime()
        state.Ensure = g_UXOfficial_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        -- Install early even when page/alias modules are still loading.
        local okHook, hookError = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookError)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        local timer = _G.__UXOfficialShotFastRunner
        return {version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            managerModuleError = state.ManagerModuleError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            pageUIKey = state.Page and state.Page.UIKey or nil,
            sliderReady = state.SliderReady == true, deferredSliderRows = state.DeferredSliderRows,
            lastShowUIInjected = state.LastShowUIInjected,
            lastShowUICatalogIndex = state.LastShowUICatalogIndex,
            maintenanceProvider = type(timer) == "table" and timer.Provider or nil,
            maintenanceError = type(timer) == "table" and timer.LastError or nil}
    end
end

-- ESP configuration made by @UXOfficial
_G.g_UXOfficial_UXOfficialShotESP = _G.g_UXOfficial_UXOfficialShotESP or {

    Enabled = true,
    MaxRangeMeters = 450.0,

    -- Target 60 updates/sec when the engine timer permits. No skeleton decimation.
    -- Discovery is separate from rendering; every rendered pose uses fresh projections.
    ScanInterval = 0.35,
    UpdateInterval = 1.0 / 60.0,
    WidgetBuildBudget = 96, -- New line widgets per update; existing widgets stay live.
    Profile = false,       -- Optional CPU timing in _G.g_UXOfficial_ESPDiagnostics.
    TransformInterval = 0.60,
    MaxRendered = 8,

    CounterY = 36.0,
    CounterWidth = 400.0,
    CounterHeight = 58.0,
    CounterDiamondSize = 0.0,

    TracerThickness = 1.80,
    NameGap = 2.0,
    NameFontSize = 14,
    DistanceFontSize = 20,
    DistanceBelowFeet = 8.0,
}
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRendered) or 0) < 1 then
    _G.g_UXOfficial_UXOfficialShotESP.MaxRendered = 8
end
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters) or 0) < 400.0 then
    _G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters = 450.0
end
-- Upgrade a table retained by an earlier hot-reload to the new readable marker size.
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 0) < 20 then
    _G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize = 20
end
-- Premium enemy/bot counter dimensions.
_G.g_UXOfficial_UXOfficialShotESP.CounterWidth=400.0
_G.g_UXOfficial_UXOfficialShotESP.CounterHeight=58.0
_G.g_UXOfficial_UXOfficialShotESP.CounterDiamondSize=0.0

-- Upgrade only the shipped 30 Hz default on the first performance revision.
if not _G.g_UXOfficial_UXOfficialShotESP.PerformanceRevision then
    if _G.g_UXOfficial_UXOfficialShotESP.UpdateInterval == 0.033 then
        _G.g_UXOfficial_UXOfficialShotESP.UpdateInterval = 1.0 / 60.0
    end
    _G.g_UXOfficial_UXOfficialShotESP.PerformanceRevision = 1
end
_G.UXOfficialShotESP = _G.g_UXOfficial_UXOfficialShotESP

-- ESP runtime state made by @UXOfficial
local g_UXOfficial_ShotESP = {
    Canvas = nil,
    RootUI = nil,
    Counter = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    Boxes = {},
    HealthBars = {},
    Skeletons = {},
    Headers = {},
    Footers = {},
    BuildStage = {},
    BoneNameCache = {},
    Decorations = {},
    TemplateFont = nil,
    TemplateFontObject = nil,
    TemplateTypeface = nil,
    TemplateColorAndOpacity = nil,
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    TracerOrigin = nil,

    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    ViewportW = nil,
    ViewportH = nil,
    RawViewportW = nil,
    RawViewportH = nil,
    HeaderRoots = {},
    Active = {},
    Alive = {},
    BoneMeshes = {},
    BonePoints = {},
    TimerClock = 0.0,
    Now = 0.0,
    Disabled = false,
    -- Bot detection result cache (avoids repeated IsAI calls every frame)
    _BotCache = {},
    RealCount = 0,
    BotCount = 0,
    RadarLines = {},
    RadarLastCanvas = nil,
    RadarUI = nil,
    RadarOpen = false,
    RadarCanvas = nil,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local V3 = _G.FVector
if not V3 then pcall(function() V3 = import("Vector") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local Anchors = _G.FAnchors
if not Anchors then pcall(function() Anchors = import("Anchors") or import("/Script/Slate.Anchors") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
local SlateColor = nil
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
local KismetTextLibrary = nil
pcall(function() KismetTextLibrary = import("KismetTextLibrary") or import("/Script/Engine.KismetTextLibrary") end)
local GameplayStaticsESP = nil
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local ESPGameplayData=nil
pcall(function() ESPGameplayData=require("GameLua.GameCore.Data.GameplayData") end)

-- g_UXOfficial_ESPV2 made by @UXOfficial
local function g_UXOfficial_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_UXOfficial_ESPV3(x, y, z)
    if V3 then
        local ok, v = pcall(V3, x, y, z)
        if ok and v then return v end
    end
    return {X = x, Y = y, Z = z}
end

-- ESP color made by @UXOfficial
local function g_UXOfficial_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

-- ESP color theme made by @UXOfficial
local ESP_REAL = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0) -- visible target: yellow
local ESP_BOT  = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0) -- visible target: yellow
local ESP_COVER_RED = g_UXOfficial_ESPColor(1.0, 0.02, 0.02, 1.0) -- target behind cover: red
local ESP_WHITE = g_UXOfficial_ESPColor(1.0, 1.0, 1.0, 1.0)
local ESP_NAME_YELLOW = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0)
local ESP_SKELETON_YELLOW = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0)
local ESP_BLACK = g_UXOfficial_ESPColor(0.0, 0.0, 0.0, 1.0)
local ESP_TEXT_CLEAR = g_UXOfficial_ESPColor(0.0,0.0,0.0,0.0)
local ESP_HEADER_BG = g_UXOfficial_ESPColor(0.0, 0.0, 0.0, 0.78)
local ESP_COUNTER_RED = g_UXOfficial_ESPColor(0.92, 0.06, 0.12, 1.0) -- dragon red
local ESP_COUNTER_RED_DARK = g_UXOfficial_ESPColor(0.055, 0.008, 0.016, 1.0) -- dragon-black panel
local ESP_COUNTER_BLUE = g_UXOfficial_ESPColor(1.0, 0.20, 0.24, 1.0) -- ember red
local ESP_COUNTER_BLUE_DARK = g_UXOfficial_ESPColor(0.10, 0.012, 0.022, 1.0) -- deep dragon shadow
local ESP_COUNTER_CENTER = g_UXOfficial_ESPColor(0.025, 0.006, 0.012, 1.0)

-- ESP gradient color made by @UXOfficial
local function g_UXOfficial_ESPScaleColor(color, factor, alphaMul)
    if not color then return g_UXOfficial_ESPColor(1, 1, 1, 1) end
    local r = math.max(0.0, math.min(1.0, (tonumber(color.R) or 1.0) * (factor or 1.0)))
    local g = math.max(0.0, math.min(1.0, (tonumber(color.G) or 1.0) * (factor or 1.0)))
    local b = math.max(0.0, math.min(1.0, (tonumber(color.B) or 1.0) * (factor or 1.0)))
    local a = math.max(0.0, math.min(1.0, (tonumber(color.A) or 1.0) * (alphaMul or 1.0)))
    return g_UXOfficial_ESPColor(r, g, b, a)
end

local ESP_REAL_DARK  = g_UXOfficial_ESPScaleColor(ESP_REAL, 0.68, 1.0)
local ESP_REAL_LIGHT = g_UXOfficial_ESPScaleColor(ESP_REAL, 1.12, 0.82)
local ESP_BOT_DARK   = g_UXOfficial_ESPScaleColor(ESP_BOT, 0.68, 1.0)
local ESP_BOT_LIGHT  = g_UXOfficial_ESPScaleColor(ESP_BOT, 1.10, 0.82)
local ESP_WHITE_SOFT = g_UXOfficial_ESPColor(0.94, 0.94, 0.94, 0.98)
local ESP_WHITE_GLOSS = g_UXOfficial_ESPColor(1.0, 1.0, 1.0, 0.34)

local g_UXOfficial_ESPTheme
do
-- APEX visual identity: solar-amber for real players, glacier-blue for bots.
-- Deep obsidian backing keeps the high-energy accents legible without a neon wash.
local ESP_REAL_THEME = {Key="APEX_SOLAR_AMBER",Main=g_UXOfficial_ESPColor(1.0,0.62,0.16,1.0),
    Light=g_UXOfficial_ESPColor(1.0,0.91,0.66,1.0),Text=g_UXOfficial_ESPColor(1.0,0.78,0.42,1.0),
    Background=g_UXOfficial_ESPColor(0.055,0.026,0.012,0.96),
    Empty=g_UXOfficial_ESPColor(0.12,0.055,0.018,1.0)}
local ESP_BOT_THEME = {Key="APEX_GLACIER_BLUE",Main=g_UXOfficial_ESPColor(0.22,0.72,1.0,1.0),
    Light=g_UXOfficial_ESPColor(0.76,0.94,1.0,1.0),Text=g_UXOfficial_ESPColor(0.48,0.84,1.0,1.0),
    Background=g_UXOfficial_ESPColor(0.012,0.042,0.075,0.96),
    Empty=g_UXOfficial_ESPColor(0.018,0.085,0.14,1.0)}
g_UXOfficial_ESPTheme=function(isBot)
    return isBot and ESP_BOT_THEME or ESP_REAL_THEME
end
end
-- ESP object validation made by @UXOfficial
local function g_UXOfficial_ESPValid(obj)
    if not obj then return false end
    if not slua or not slua.isValid then return false end
    local ok, valid = pcall(slua.isValid, obj)
    return ok and valid == true
end

local ESPShared={}
function ESPShared.Finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function ESPShared.SafeNumber(value,fallback,lo,hi)
    local n=tonumber(value)
    if not ESPShared.Finite(n) then n=fallback end
    return math.max(lo,math.min(hi,n))
end
function ESPShared.VectorComponents(v) return tonumber(v.X),tonumber(v.Y),tonumber(v.Z) end
function ESPShared.VectorValues(v)
    if v==nil then return nil end
    local ok,x,y,z=pcall(ESPShared.VectorComponents,v)
    if ok and ESPShared.Finite(x) and ESPShared.Finite(y) and ESPShared.Finite(z)
        and math.abs(x)<1e12 and math.abs(y)<1e12 and math.abs(z)<1e12 then return x,y,z end
end

-- ESP timing made by @UXOfficial
local function g_UXOfficial_ESPNow()
    local t = nil
    pcall(function()
        local w = (slua and slua.getWorld and slua.getWorld()) or nil
        if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
            t = GameplayStaticsESP.GetRealTimeSeconds(w)
        end
    end)
    t=tonumber(t)
    if ESPShared.Finite(t) and t>=0 then return t end
    -- os.clock measures CPU time on some platforms, not elapsed frame time.
    -- If the engine clock is unavailable, advance by executed timer delays.
    return ESPShared.SafeNumber(g_UXOfficial_ShotESP.TimerClock,0.0,0.0,1e12)
end

-- ESP world access made by @UXOfficial
local function g_UXOfficial_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

-- ESP player controller made by @UXOfficial
local function g_UXOfficial_ESPGetController()
    local pc = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
    end)
    if not g_UXOfficial_ESPValid(pc) then
        pcall(function()
            if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
        end)
    end
    return g_UXOfficial_ESPValid(pc) and pc or nil
end

-- ESP local player made by @UXOfficial
local function g_UXOfficial_ESPGetLocalCharacter()
    local c = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP then
            if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
            if not g_UXOfficial_ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
        end
    end)
    if not g_UXOfficial_ESPValid(c) then
        local pc = g_UXOfficial_ESPGetController()
        pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
    end
    return g_UXOfficial_ESPValid(c) and c or nil
end

-- g_UXOfficial_ESPGetPlayerState made by @UXOfficial
local function g_UXOfficial_ESPGetPlayerState(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_UXOfficial_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_UXOfficial_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_UXOfficial_ESPValid(ps) and ps or nil
end

-- g_UXOfficial_ESPNormalizeName made by @UXOfficial
local function g_UXOfficial_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" or text == "UNKNOWN" then return nil end
    if text:find("^userdata:") or text:find("^table:") then return nil end
    return text
end

-- ESP player name made by @UXOfficial
local function g_UXOfficial_ESPResolvePlayerName(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local name = nil

-- take made by @UXOfficial
    local function take(value)
        if not name then name = g_UXOfficial_ESPNormalizeName(value) end
    end

    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    pcall(function() if not name then take(character.AIPlayerName) end end)
    pcall(function() if not name then take(character.BotName) end end)

    if not name then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
            pcall(function() if not name then take(ps.AccountName) end end)
            pcall(function() if not name then take(ps.AIPlayerName) end end)
        end
    end
    return name
end

-- g_UXOfficial_ESPGetPlayerKey made by @UXOfficial
local function g_UXOfficial_ESPGetPlayerKey(character)
    local key = nil
    pcall(function() if character.GetPlayerKey then key = character:GetPlayerKey() end end)
    if key == nil then pcall(function() key = character.PlayerKey end) end
    if key == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then pcall(function() key = ps.PlayerKey end) end
    end
    if key == nil or tostring(key) == "" or tostring(key) == "0" or tostring(key) == "-1" then
        return tostring(character)
    end
    return tostring(key) .. "_" .. tostring(character)
end

-- ESP team detection made by @UXOfficial
local function g_UXOfficial_ESPGetTeamID(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

-- ESP alive detection made by @UXOfficial
local ESPFinishedLastBreath,ESPDeadPawnState
pcall(function() ESPFinishedLastBreath=import("ECharacterHealthStatus").FinishedLastBreath end)
pcall(function() ESPDeadPawnState=EPawnState and EPawnState.Dead end)
local function ESPActorField(actor,key) return actor[key] end
local function ESPReadActorField(actor,key)
    local ok,value=pcall(ESPActorField,actor,key)
    if ok then return value end
end
local function ESPReadActorMethod(actor,key,...)
    local method=ESPReadActorField(actor,key)
    if type(method)=="function" then
        local ok,value=pcall(method,actor,...)
        if ok then return value end
    end
end
local function ESPActorDeadFlag(actor,key)
    local value=ESPReadActorField(actor,key)
    return value==true or value==1
end
local function g_UXOfficial_ESPIsAlive(character)
    if not g_UXOfficial_ESPValid(character) then return false end
    if ESPActorDeadFlag(character,"bDead") or ESPActorDeadFlag(character,"bIsDead")
        or ESPActorDeadFlag(character,"bIsDeadFlag") then return false end
    if ESPFinishedLastBreath~=nil
        and ESPReadActorField(character,"HealthStatus")==ESPFinishedLastBreath then return false end
    if ESPDeadPawnState~=nil
        and ESPReadActorMethod(character,"HasPawnState",ESPDeadPawnState)==true then return false end
    if ESPReadActorMethod(character,"IsDead")==true then return false end
    local alive=ESPReadActorMethod(character,"IsAlive")
    -- A native alive result retains knocked players; terminal death above wins.
    if type(alive)=="boolean" then return alive end
    local hp=ESPReadActorField(character,"Health")
    if type(hp)~="number" then hp=ESPReadActorField(character,"HP") end
    if type(hp)~="number" then hp=ESPReadActorMethod(character,"GetHealth") end
    if type(hp)=="number" then return hp==hp and hp>0 end
    return true
end

-- Bot cache uses the same actor/player key as pruning, with replication retries.
local function g_UXOfficial_ESPIsBot(character, key, providedCache, providedNow)
    if not g_UXOfficial_ESPValid(character) then return false end
    key = key or g_UXOfficial_ESPGetPlayerKey(character)
    local cache = providedCache or g_UXOfficial_ShotESP._BotCache
    local now = providedNow or g_UXOfficial_ShotESP.Now
    local entry = cache[key]
    if entry and now >= entry.Clock and now - entry.Clock < 2.0 then return entry.Value end
    local result = nil
    local function take(v)
        if result == nil and (v == true or v == false or v == 1 or v == 0) then
            result = (v == true or v == 1)
        end
    end
    pcall(function() if Game and Game.IsAI then take(Game:IsAI(character)) end end)
    if result == nil then pcall(function() take(character.bIsAI) end) end
    if result == nil then pcall(function() if character.IsBot then take(character:IsBot()) end end) end
    if result == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() take(ps.bIsABot) end)
            pcall(function() take(ps.bIsBot) end)
            pcall(function() take(ps.bIsAI) end)
            if result == nil then pcall(function() if ps.IsBot then take(ps:IsBot()) end end) end
        end
    end
    -- Unresolved replication data is never cached as a permanent false.
    cache[key] = result ~= nil and {Value=result, Clock=now} or nil
    return result == true
end

-- ESP actor position made by @UXOfficial
local function g_UXOfficial_ESPActorLocation(character)
    local loc = nil
    if not g_UXOfficial_ESPValid(character) then return nil end
    pcall(function()
        if character.K2_GetActorLocation then loc = character:K2_GetActorLocation()
        elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(character) end
    end)
    return loc
end

-- ESP distance calculation made by @UXOfficial
local function g_UXOfficial_ESPDistanceMeters(a,b)
    local ax,ay,az=ESPShared.VectorValues(a)
    local bx,by,bz=ESPShared.VectorValues(b)
    if not ax or not bx then return math.huge end
    local dx,dy,dz=ax-bx,ay-by,az-bz
    return math.sqrt(dx*dx+dy*dy+dz*dz)/100.0
end


-- A memo lives for one scheduler callback only.
-- Callback-local values never retain actors, controllers or native locations
-- after Finish. The bounded pool keeps only reusable vector buffers.
ESPShared.Frame={Active=false,Entries={},Pool={},PoolLimit=256,Now=0,ViewAt=-999,Controllers={},Transforms={},TransformPool={}}
function ESPShared.Frame.Finish()
    local frame=ESPShared.Frame
    for actor,entry in pairs(frame.Entries) do
        frame.Entries[actor]=nil
        entry.Location=nil;entry.LocationX=nil;entry.LocationY=nil;entry.LocationZ=nil
        entry.DistanceOrigin=nil;entry.DistanceSquared=nil;entry.DistanceMeters=nil
        entry.Alive=false;entry.Projected=false;entry.OnScreen=false
        entry.HasHead=false;entry.HasFeet=false;entry.PC=nil
        if #frame.Pool<frame.PoolLimit then frame.Pool[#frame.Pool+1]=entry end
    end
    for pc in pairs(frame.Controllers) do frame.Controllers[pc]=nil end
    for state,value in pairs(frame.Transforms) do
        frame.Transforms[state]=nil
        if #frame.TransformPool<4 then frame.TransformPool[#frame.TransformPool+1]=value end
    end
    frame.DistanceOrigin=nil;frame.OriginX=nil;frame.OriginY=nil;frame.OriginZ=nil
    frame.Pawns=nil;frame.Active=false
end
function ESPShared.Frame.Begin(now)
    ESPShared.Frame.Finish()
    ESPShared.Frame.Now=now;ESPShared.Frame.Active=true
end
function ESPShared.GetFrameRecord(actor)
    local frame=ESPShared.Frame
    local entry=frame.Active and frame.Entries[actor]
    if entry then return entry end
    entry=frame.Active and table.remove(frame.Pool) or nil
    if not entry then entry={} end
    entry.Alive=g_UXOfficial_ESPIsAlive(actor)
    entry.Projected=false;entry.OnScreen=false;entry.HasHead=false;entry.HasFeet=false
    entry.Location=entry.Alive and g_UXOfficial_ESPActorLocation(actor) or nil
    entry.LocationX,entry.LocationY,entry.LocationZ=ESPShared.VectorValues(entry.Location)
    if not entry.LocationX then entry.Location=nil end
    if frame.Active and actor~=nil then frame.Entries[actor]=entry end
    return entry
end
function ESPShared.GetFramePawns()
    if ESPShared.Frame.Active and ESPShared.Frame.Pawns then return ESPShared.Frame.Pawns end
    local pawns
    pcall(function() if Game and Game.GetAllPlayerPawns then pawns=Game:GetAllPlayerPawns() end end)
    if ESPShared.Frame.Active then ESPShared.Frame.Pawns=pawns end
    return pawns
end
function ESPShared.DistanceSquaredFrom(entry,origin)
    if not entry or not entry.LocationX then return math.huge end
    local frame=ESPShared.Frame
    if frame.Active and entry.DistanceOrigin==origin and entry.DistanceSquared~=nil then return entry.DistanceSquared end
    local x,y,z
    if frame.Active and frame.DistanceOrigin==origin then
        x,y,z=frame.OriginX,frame.OriginY,frame.OriginZ
    else
        x,y,z=ESPShared.VectorValues(origin)
        if frame.Active then frame.DistanceOrigin=origin;frame.OriginX=x;frame.OriginY=y;frame.OriginZ=z end
    end
    if not x then
        if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=math.huge;entry.DistanceMeters=nil end
        return math.huge
    end
    local dx,dy,dz=x-entry.LocationX,y-entry.LocationY,z-entry.LocationZ
    local squared=dx*dx+dy*dy+dz*dz
    if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=squared;entry.DistanceMeters=nil end
    return squared
end
function ESPShared.DistanceMetersFrom(entry,origin)
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if ESPShared.Frame.Active and entry.DistanceMeters~=nil then return entry.DistanceMeters end
    local distance=math.sqrt(squared)/100.0
    if ESPShared.Frame.Active then entry.DistanceMeters=distance end
    return distance
end
function ESPShared.InRange(entry,origin,maxRange)
    if not ESPShared.Finite(maxRange) or maxRange<=0 then return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange end
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if squared==math.huge then return false end
    local limit=maxRange*100.0;limit=limit*limit
    -- Preserve the original sqrt/division decision at floating-point boundaries.
    if math.abs(squared-limit)<=math.max(1,limit)*1e-12 then
        return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange
    end
    return squared<limit
end
function ESPShared.ProjectionControllerValid(pc)
    if pc==nil then return false end
    local frame=ESPShared.Frame
    if frame.Active then
        local cached=frame.Controllers[pc]
        if cached~=nil then return cached end
        local valid=g_UXOfficial_ESPValid(pc);frame.Controllers[pc]=valid;return valid
    end
    return g_UXOfficial_ESPValid(pc)
end
function ESPShared.CanvasTransform(state)
    local frame=ESPShared.Frame
    local value=frame.Active and frame.Transforms[state]
    local rx,ry,rox,roy=state.CanvasScaleX,state.CanvasScaleY,state.CanvasOffsetX,state.CanvasOffsetY
    if not value or value.RX~=rx or value.RY~=ry or value.ROX~=rox or value.ROY~=roy then
        value=value or (frame.Active and table.remove(frame.TransformPool)) or {}
        value.RX=rx;value.RY=ry;value.ROX=rox;value.ROY=roy
        value.SX=ESPShared.SafeNumber(rx,1,0.00001,100)
        value.SY=ESPShared.SafeNumber(ry,1,0.00001,100)
        value.OX=ESPShared.SafeNumber(rox,0,-1e7,1e7)
        value.OY=ESPShared.SafeNumber(roy,0,-1e7,1e7)
        if frame.Active then frame.Transforms[state]=value end
    end
    return value.SX,value.SY,value.OX,value.OY
end
function ESPShared.AssignProbeVector(vector,x,y,z)
    vector.X=x;vector.Y=y;vector.Z=z
end
function ESPShared.UpdateProbeVector(vector,x,y,z)
    if vector and pcall(ESPShared.AssignProbeVector,vector,x,y,z) then return vector end
    return g_UXOfficial_ESPV3(x,y,z)
end

-- Validate all cached candidates before display caps. Reuse the list and alive
-- map, so dead/out-of-range actors are pruned on the next scheduled HUD update.
local function g_UXOfficial_ESPFilterEnemies(list, myLocation, maxRange, alive)
    for key in pairs(alive) do alive[key]=nil end
    local count,kept,realCount,botCount=#list,0,0,0
    maxRange=tonumber(maxRange) or 450.0
    if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
    for i=1,count do
        local item=list[i]
        local character=item and item.Character
        local snapshot=item and item.Key and ESPShared.GetFrameRecord(character)
        if snapshot and snapshot.Alive then
            local location=snapshot.Location
            local distance=ESPShared.DistanceMetersFrom(snapshot,myLocation)
            if distance<=maxRange then
                item.Distance=distance
                kept=kept+1;list[kept]=item;alive[item.Key]=true
                if item.IsBot then botCount=botCount+1 else realCount=realCount+1 end
            end
        end
    end
    for i=kept+1,count do list[i]=nil end
    return realCount,botCount
end

-- ESP character vertical bounds made by @UXOfficial
local function g_UXOfficial_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not g_UXOfficial_ESPValid(character) then return nil, nil end

    local center, halfHeight = nil, nil
    local capsule = nil

    pcall(function()
        if character.GetCapsuleComponent then
            capsule = character:GetCapsuleComponent()
        elseif character.CapsuleComponent then
            capsule = character.CapsuleComponent
        end
    end)

    if capsule and g_UXOfficial_ESPValid(capsule) then
        pcall(function()
            if capsule.K2_GetComponentLocation then
                center = capsule:K2_GetComponentLocation()
            elseif capsule.GetComponentLocation then
                center = capsule:GetComponentLocation()
            end

            if capsule.GetScaledCapsuleHalfHeight then
                halfHeight = capsule:GetScaledCapsuleHalfHeight()
            elseif capsule.GetUnscaledCapsuleHalfHeight then
                halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
            elseif capsule.CapsuleHalfHeight then
                halfHeight = capsule.CapsuleHalfHeight
            end
        end)
    end

    local cx,cy,cz=ESPShared.VectorValues(center)
    if center and not cx then center=nil end
    if not center then center=cachedLocation end
    if not center then
        pcall(function()
            if character.K2_GetActorLocation then
                center = character:K2_GetActorLocation()
            end
        end)
    end

    if not center then
        pcall(function()
            if Game and Game.GetActorLocation then
                center = Game:GetActorLocation(character)
            end
        end)
    end

    if not cx then cx,cy,cz=ESPShared.VectorValues(center) end
    if not cx then return nil,nil end

    halfHeight=tonumber(halfHeight)
    if not ESPShared.Finite(halfHeight) or halfHeight<10 or halfHeight>200 then
        halfHeight = 85
        pcall(function()
            if character.bIsCrouched then halfHeight = 60 end
            if character.IsProne and character:IsProne() then halfHeight = 25 end
        end)
    end

    return center, halfHeight, cx, cy, cz
end

-- ESP head and feet position made by @UXOfficial
local function g_UXOfficial_ESPGetCharacterBoxLocs(character,cachedLocation)
    local center, halfHeight, x, y, z = g_UXOfficial_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not x or not halfHeight then return nil,nil end

    local headLoc = g_UXOfficial_ESPV3(
        x,
        y,
        z + halfHeight
    )

    local feetLoc = g_UXOfficial_ESPV3(
        x,
        y,
        z - halfHeight
    )

    return headLoc, feetLoc, center
end

-- ESP head position made by @UXOfficial

-- ESP feet position made by @UXOfficial

-- Bounded inactive HUD widgets. Records retain native widget/slot structure,
-- never an enemy key, actor, name, delegate, bone mesh or controller. Collapsed
-- widgets stay under the same canvas so reuse does not allocate CanvasSlots.
local ESPWidgetPool={}
do
local shapes={
    Line={Fields={"Widget","Slot","PosVec","SizeVec","VectorReuseDisabled"},Check={"Widget","Slot"},Limit=256},
    NameV2={Fields={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},Limit=16},
    Decor={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
    Header={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
}
local function remove(widget)
    if widget then pcall(function() widget:RemoveFromParent() end) end
end
local function weight(data)
    local count=1
    if data.Groups then
        for _,group in pairs(data.Groups) do count=count+#group end
    elseif data.Text then count=data.BottomLine and 6 or 3 end
    return count
end
local function resetGroups(groups)
    if not groups then return end
    for _,group in pairs(groups) do
        for field in pairs(group) do if type(field)~="number" then group[field]=nil end end
        for _,piece in ipairs(group) do
            local w,s,pv,sv,disabled=piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled
            for field in pairs(piece) do piece[field]=nil end
            piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled=w,s,pv,sv,disabled
            piece.Visible=false
        end
    end
end
function ESPWidgetPool.New(capacity)
    return {Bins={},Canvas=nil,Enabled=true,Weight=0,Capacity=capacity,
        Reused=0,Released=0,Created=0,Discarded=0}
end
ESPWidgetPool.V2=ESPWidgetPool.New(1024)
function ESPWidgetPool.Flush(pool)
    for kind,bin in pairs(pool.Bins) do
        for i=#bin,1,-1 do
            local item=bin[i];bin[i]=nil;remove(item.Widget)
            for key in pairs(item) do item[key]=nil end
        end
        pool.Bins[kind]=nil
    end
    pool.Canvas=nil;pool.Weight=0
end
function ESPWidgetPool.Tag(pool,kind,canvas,data)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    data.PoolOwner=pool;data.PoolKind=kind;data.PoolCanvas=canvas
    pool.Created=pool.Created+1
    return data
end
function ESPWidgetPool.Release(data)
    if data.PoolReleased then return true end
    local pool,kind,canvas=data.PoolOwner,data.PoolKind,data.PoolCanvas
    if not pool or not pool.Enabled or pool.Canvas~=canvas or data.Broken
        or not g_UXOfficial_ESPValid(data.Widget) then return false end
    local shape=shapes[kind]
    if not shape then return false end
    local bin=pool.Bins[kind]
    if not bin then bin={};pool.Bins[kind]=bin end
    local cost=weight(data)
    if #bin>=shape.Limit or pool.Weight+cost>pool.Capacity then return false end
    local ok=pcall(function()
        data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        if data.Text then data.Text:SetText("") end
        if data.DistanceText then data.DistanceText:SetText("") end
        if data.Groups then
            for _,group in pairs(data.Groups) do
                for _,piece in ipairs(group) do
                    if piece.Broken then error("POOL_BROKEN_PIECE") end
                    if piece.Visible~=false then
                        piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end
        end
    end)
    if not ok then return false end
    resetGroups(data.Groups)
    local item={Weight=cost}
    for _,field in ipairs(shape.Fields) do item[field]=data[field] end
    -- Clear even caller-added fields so a reference never follows another enemy.
    for field in pairs(data) do data[field]=nil end
    data.PoolReleased=true
    bin[#bin+1]=item;pool.Weight=pool.Weight+cost;pool.Released=pool.Released+1
    return true
end
function ESPWidgetPool.Take(pool,kind,canvas)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    if not pool.Enabled then return nil end
    local shape,bin=shapes[kind],pool.Bins[kind]
    if not shape or not bin then return nil end
    while #bin>0 do
        local item=bin[#bin];bin[#bin]=nil;pool.Weight=pool.Weight-item.Weight
        local valid=true
        for _,field in ipairs(shape.Check) do
            if not g_UXOfficial_ESPValid(item[field]) then valid=false;break end
        end
        if valid and item.Groups then
            for _,group in pairs(item.Groups) do
                for _,piece in ipairs(group) do
                    if not g_UXOfficial_ESPValid(piece.Widget) or not g_UXOfficial_ESPValid(piece.Slot) then
                        valid=false;break
                    end
                end
                if not valid then break end
            end
        end
        -- Missing bindings or externally detached/reparented widgets fall back
        -- to normal construction, rather than assuming their CanvasSlot works.
        if valid then
            local ok,parent=pcall(function() return item.Widget:GetParent() end)
            valid=ok and parent==canvas
        end
        if valid then
            local data={PoolOwner=pool,PoolKind=kind,PoolCanvas=canvas}
            for _,field in ipairs(shape.Fields) do data[field]=item[field] end
            resetGroups(data.Groups)
            pool.Reused=pool.Reused+1
            return data
        end
        remove(item.Widget);pool.Discarded=pool.Discarded+1
        for key in pairs(item) do item[key]=nil end
    end
    return nil
end
end

-- ESP widget destroy made by @UXOfficial
local function g_UXOfficial_ESPDestroyWidgetData(data)
    if not data then return end
    if ESPWidgetPool.Release(data) then return end
    for _, field in ipairs({"Widget", "Container", "Text", "DistanceText"}) do
        local widget=data[field]
        if g_UXOfficial_ESPValid(widget) then
            pcall(function() widget:RemoveFromParent() end)
        end
    end
end

-- ESP widget cleanup made by @UXOfficial
local function g_UXOfficial_ESPResetWidgets()
    local radarUI=g_UXOfficial_ShotESP.RadarUI
    if radarUI then
        for _,eventName in ipairs({"ToggleEvent","CloseEvent"}) do
            local event=radarUI[eventName]
            local handle=radarUI[eventName.."Handle"]
            if event and handle~=nil then pcall(function() event:Remove(handle) end) end
        end
        for _,widgetName in ipairs({"ToggleLabel","ToggleButton","CloseLabel","CloseButton"}) do
            local widget=radarUI[widgetName]
            if widget and g_UXOfficial_ESPValid(widget) then pcall(function() widget:RemoveFromParent() end) end
        end
    end
    g_UXOfficial_ShotESP.RadarUI=nil
    g_UXOfficial_ShotESP.RadarCanvas=nil
    ESPWidgetPool.V2.Enabled=false
    for _, data in pairs(g_UXOfficial_ShotESP.Lines) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_UXOfficial_ShotESP.Names) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_UXOfficial_ShotESP.RadarLines or {}) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, group in pairs(g_UXOfficial_ShotESP.Boxes) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.HealthBars) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Skeletons) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Headers) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Footers) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    g_UXOfficial_ShotESP.Lines = {}
    g_UXOfficial_ShotESP.RadarLines = {}
    g_UXOfficial_ShotESP.Names = {}
    g_UXOfficial_ShotESP.Boxes = {}
    g_UXOfficial_ShotESP.HealthBars = {}
    g_UXOfficial_ShotESP.Skeletons = {}
    for _, data in pairs(g_UXOfficial_ShotESP.HeaderRoots) do g_UXOfficial_ESPDestroyWidgetData(data) end
    g_UXOfficial_ShotESP.HeaderRoots = {}
    g_UXOfficial_ShotESP.Headers = {}
    g_UXOfficial_ShotESP.Footers = {}
    g_UXOfficial_ShotESP.BuildStage = {}
    g_UXOfficial_ShotESP.BoneNameCache = {}
    for _,data in pairs(g_UXOfficial_ShotESP.Decorations) do g_UXOfficial_ESPDestroyWidgetData(data) end
    g_UXOfficial_ShotESP.Decorations = {}
    if g_UXOfficial_ShotESP.Counter then g_UXOfficial_ESPDestroyWidgetData(g_UXOfficial_ShotESP.Counter) end
    g_UXOfficial_ShotESP.Counter = nil
    g_UXOfficial_ShotESP.Canvas = nil
    g_UXOfficial_ShotESP.RootUI = nil
    g_UXOfficial_ShotESP.Enemies = {}
    g_UXOfficial_ShotESP.Active = {}
    g_UXOfficial_ShotESP.Alive = {}
    g_UXOfficial_ShotESP.BoneMeshes = {}
    g_UXOfficial_ShotESP.BonePoints = {}
    g_UXOfficial_ShotESP.TemplateFont = nil
    g_UXOfficial_ShotESP.TemplateFontObject = nil
    g_UXOfficial_ShotESP.TemplateTypeface = nil
    g_UXOfficial_ShotESP.TemplateColorAndOpacity = nil
    g_UXOfficial_ShotESP.ViewportW, g_UXOfficial_ShotESP.ViewportH = nil, nil
    g_UXOfficial_ShotESP.RawViewportW, g_UXOfficial_ShotESP.RawViewportH = nil, nil
    g_UXOfficial_ShotESP.TracerOrigin = nil
    g_UXOfficial_ShotESP.LastScanClock = -999.0
    g_UXOfficial_ShotESP.LastTransformClock = -999.0
    g_UXOfficial_ShotESP.LastController = nil
    g_UXOfficial_ShotESP.LastPawn = nil
    g_UXOfficial_ShotESP._BotCache = {}
    g_UXOfficial_ShotESP.RealCount = 0
    g_UXOfficial_ShotESP.BotCount = 0
    ESPWidgetPool.Flush(ESPWidgetPool.V2)
    ESPWidgetPool.V2.Enabled=true
end

-- ESP HUD canvas made by @UXOfficial
local function g_UXOfficial_ESPGetCanvas()
    if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.Canvas) then return g_UXOfficial_ShotESP.Canvas end
    local root = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
    end)
    if not g_UXOfficial_ESPValid(root) then return nil end
    g_UXOfficial_ShotESP.RootUI = root
    local canvas = nil
    pcall(function()
        if g_UXOfficial_ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
        elseif g_UXOfficial_ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
    end)
    if g_UXOfficial_ESPValid(canvas) then g_UXOfficial_ShotESP.Canvas = canvas return canvas end
    return nil
end

-- Discover a valid FontObject from existing HUD TextBlocks so dynamic TextBlocks always render glyphs
local function g_UXOfficial_ESPGetTemplateTextStyle()
    if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) then
        return g_UXOfficial_ShotESP.TemplateFont
    end

    local visited = 0
    local function scanWidget(w, depth)
        if not w or depth > 6 or visited > 250 then return false end
        if not g_UXOfficial_ESPValid(w) then return false end
        visited = visited + 1

        local found = false
        pcall(function()
            if w.SetText and w.SetFont and w.Font then
                local f = w.Font
                if f and g_UXOfficial_ESPValid(f.FontObject) then
                    g_UXOfficial_ShotESP.TemplateFont = f
                    g_UXOfficial_ShotESP.TemplateFontObject = f.FontObject
                    pcall(function() g_UXOfficial_ShotESP.TemplateTypeface = f.TypefaceFontName end)
                    pcall(function() g_UXOfficial_ShotESP.TemplateColorAndOpacity = w.ColorAndOpacity end)
                    found = true
                end
            end
        end)
        if found then return true end

        local childCount = 0
        pcall(function() if w.GetChildrenCount then childCount = tonumber(w:GetChildrenCount()) or 0 end end)
        for i = 0, childCount - 1 do
            local child = nil
            pcall(function() child = w:GetChildAt(i) end)
            if child and scanWidget(child, depth + 1) then return true end
        end

        local treeRoot = nil
        pcall(function() if w.WidgetTree and w.WidgetTree.RootWidget then treeRoot = w.WidgetTree.RootWidget end end)
        if treeRoot and treeRoot ~= w and scanWidget(treeRoot, depth + 1) then return true end

        return false
    end

    local canvas = g_UXOfficial_ESPGetCanvas()
    if canvas then scanWidget(canvas, 0) end
    if not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) and g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.RootUI) then
        scanWidget(g_UXOfficial_ShotESP.RootUI, 0)
    end

    if not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) and slua and slua.loadObject then
        for _, path in ipairs({
            "/Engine/EngineFonts/Roboto.Roboto",
            "/Engine/EngineFonts/Roboto",
            "/Engine/EngineFonts/DroidSansFallback.DroidSansFallback"
        }) do
            local ok, obj = pcall(slua.loadObject, path)
            if ok and g_UXOfficial_ESPValid(obj) then
                g_UXOfficial_ShotESP.TemplateFontObject = obj
                break
            end
        end
    end

    return g_UXOfficial_ShotESP.TemplateFont
end

-- ESP viewport size made by @UXOfficial
local function g_UXOfficial_ESPViewport(pc)
    local w,h
    local function take(x,y)
        x,y=tonumber(x),tonumber(y)
        if ESPShared.Finite(x) and ESPShared.Finite(y) and x>200 and y>200 and x<1e6 and y<1e6 then w,h=x,y;return true end
    end
    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
            local v=WidgetLayoutLibrary.GetViewportSize(pc);if v then take(v.X,v.Y) end
        end
    end)
    if not w then pcall(function() local x,y=pc:GetViewportSize();take(x,y) end) end
    if not w then pcall(function() local v=g_UXOfficial_ESPV2(0,0);pc:GetViewportSize(v);take(v.X,v.Y) end) end
    if not w then pcall(function() local x,y=pc:GetViewportSize(0,0);take(x,y) end) end
    return w or 2400.0,h or 1080.0
end

-- ESP HUD canvas made by @UXOfficial
local function g_UXOfficial_ESPGetCanvasLocalSize()
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil, nil end

    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end

        local size = nil
        if geo.GetLocalSize then
            size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then
            size = SlateBlueprintLibrary.GetLocalSize(geo)
        end

        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 100 and size.Y > 100 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)

    return cw, ch
end

-- ESP canvas transform made by @UXOfficial
local function g_UXOfficial_ESPUpdateCanvasTransform(pc)
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return false end

    local calibrated = false

    pcall(function()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local geo = canvas:GetCachedGeometry()
            if geo then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_UXOfficial_ESPV2(0, 0)
                )
                local p1 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_UXOfficial_ESPV2(100, 100)
                )

                if p0 and p1
                    and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                    and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                    and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                    and p1.X>p0.X and p1.Y>p0.Y
                    and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then

                    g_UXOfficial_ShotESP.CanvasScaleX = (p1.X - p0.X) / 100.0
                    g_UXOfficial_ShotESP.CanvasScaleY = (p1.Y - p0.Y) / 100.0
                    g_UXOfficial_ShotESP.CanvasOffsetX = p0.X
                    g_UXOfficial_ShotESP.CanvasOffsetY = p0.Y
                    calibrated = true
                end
            end
        end
    end)

    if not calibrated then
        local scale = 1.0
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then
                    scale = s
                end
            end
        end)

        g_UXOfficial_ShotESP.CanvasScaleX = 1.0 / scale
        g_UXOfficial_ShotESP.CanvasScaleY = 1.0 / scale
        g_UXOfficial_ShotESP.CanvasOffsetX = 0.0
        g_UXOfficial_ShotESP.CanvasOffsetY = 0.0
    end

    return true
end

-- ESP world to HUD projection made by @UXOfficial
local function g_UXOfficial_ESPProject(pc,worldLoc)
    local frame=ESPShared.Frame
    -- Skeleton results own their output; only the immediate raw scratch is shared.
    if not frame.RawPixel then frame.RawPixel=g_UXOfficial_ESPV2(0,0) end
    local pix=ESPShared.ProjectRaw(pc,worldLoc,frame.Active and frame.RawPixel or nil)
    if not pix then return nil end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(g_UXOfficial_ShotESP)
    return g_UXOfficial_ESPV2(pix.X*sx+ox,pix.Y*sy+oy)
end

-- Fresh projections deliberately avoid screen-space lerp: it adds camera lag
-- and desynchronizes the capsule outline from the independently projected bones.

local function g_UXOfficial_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    local function usable(p)
        return p and ESPShared.Finite(p.X) and ESPShared.Finite(p.Y)
    end
    head=usable(head) and head or nil;feet=usable(feet) and feet or nil
    if not head and not feet then return false end
    head=head or feet;feet=feet or head
    return math.max(head.X,feet.X)>=minX and math.min(head.X,feet.X)<=maxX
        and math.max(head.Y,feet.Y)>=minY and math.min(head.Y,feet.Y)<=maxY
end

function ESPShared.ViewSize(pc)
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_UXOfficial_ESPNow()
    if not ESPShared.Frame.Active or ESPShared.Frame.ViewPC~=pc or now<ESPShared.Frame.ViewAt or now-ESPShared.Frame.ViewAt>=0.25 then
        ESPShared.Frame.ViewW,ESPShared.Frame.ViewH=g_UXOfficial_ESPViewport(pc)
        ESPShared.Frame.ViewPC=pc;ESPShared.Frame.ViewAt=now
    end
    return ESPShared.Frame.ViewW,ESPShared.Frame.ViewH
end
function ESPShared.NativeProject(pc,location,pix)
    return pc:ProjectWorldLocationToScreen(location,pix,true)
end
function ESPShared.ActorProbeLocations(actor,entry)
    local center,height,x,y,z=g_UXOfficial_ESPGetCharacterVerticalBounds(actor,entry.Location)
    if not x or not height then return nil,nil end
    entry.WorldHead=ESPShared.UpdateProbeVector(entry.WorldHead,x,y,z+height)
    entry.WorldFeet=ESPShared.UpdateProbeVector(entry.WorldFeet,x,y,z-height)
    return entry.WorldHead,entry.WorldFeet
end
function ESPShared.ProjectRaw(pc,location,pix)
    if not ESPShared.VectorValues(location) or not ESPShared.ProjectionControllerValid(pc) then return nil end
    pix=pix or g_UXOfficial_ESPV2(0,0);pix.X=0;pix.Y=0
    local ok,result,out=pcall(ESPShared.NativeProject,pc,location,pix)
    if out then pix=out end
    local good,x,y=pcall(function() return tonumber(pix.X),tonumber(pix.Y) end)
    if not ok or not good or not ESPShared.Finite(x) or not ESPShared.Finite(y) or math.abs(x)>=1e7 or math.abs(y)>=1e7 then return nil end
    if result~=true and result~=1 and not (result==nil and (x~=0 or y~=0)) then return nil end
    return pix
end
function ESPShared.ProbeActor(pc,actor)
    local entry=ESPShared.GetFrameRecord(actor)
    if entry.Projected and entry.PC==pc then return entry end
    entry.Projected=true;entry.PC=pc;entry.OnScreen=false
    if not entry.Alive or not entry.Location then return entry end
    local ok,head,feet=pcall(ESPShared.ActorProbeLocations,actor,entry)
    if not ok then return entry end
    entry.RawHead=entry.RawHead or g_UXOfficial_ESPV2(0,0)
    entry.RawFeet=entry.RawFeet or g_UXOfficial_ESPV2(0,0)
    local hp=ESPShared.ProjectRaw(pc,head,entry.RawHead)
    local fp=ESPShared.ProjectRaw(pc,feet,entry.RawFeet)
    if hp then entry.RawHead=hp end;if fp then entry.RawFeet=fp end
    entry.HasHead=hp~=nil;entry.HasFeet=fp~=nil
    local width,height=ESPShared.ViewSize(pc)
    entry.OnScreen=g_UXOfficial_ESPActorOnScreen(hp,fp,0,0,width,height)
    return entry
end
function ESPShared.CanvasBounds(pc,state)
    local width,height=ESPShared.ViewSize(pc)
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local maxX,maxY=ox+width*sx,oy+height*sy
    if ESPShared.Finite(state.ViewportW) and state.ViewportW>1 then maxX=math.min(maxX,ox+state.ViewportW) end
    if ESPShared.Finite(state.ViewportH) and state.ViewportH>1 then maxY=math.min(maxY,oy+state.ViewportH) end
    return ox,oy,maxX,maxY
end
function ESPShared.ProjectActor(pc,actor,state)
    local entry=ESPShared.ProbeActor(pc,actor)
    if not entry.OnScreen then return nil,nil,false end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local prefix="V2"
    local function convert(raw,field)
        local p=entry[field] or g_UXOfficial_ESPV2(0,0);entry[field]=p
        p.X=raw.X*sx+ox;p.Y=raw.Y*sy+oy;return p
    end
    local head=entry.HasHead and convert(entry.RawHead,prefix.."Head") or nil
    local feet=entry.HasFeet and convert(entry.RawFeet,prefix.."Feet") or nil
    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,state)
    return head,feet,g_UXOfficial_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
end


-- ESP text setter with FText conversion fallback

-- ESP font style made by @UXOfficial
local function g_UXOfficial_ESPSetFont(textWidget, size)
    if not g_UXOfficial_ESPValid(textWidget) then return end
    g_UXOfficial_ESPGetTemplateTextStyle()
    pcall(function()
        local f = textWidget.Font or g_UXOfficial_ShotESP.TemplateFont
        if f then
            if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) then
                pcall(function() f.FontObject = g_UXOfficial_ShotESP.TemplateFontObject end)
            end
            if g_UXOfficial_ShotESP.TemplateTypeface then
                pcall(function() f.TypefaceFontName = g_UXOfficial_ShotESP.TemplateTypeface end)
            end
            pcall(function() f.Size = size end)
            if f.OutlineSettings then
                pcall(function()
                    local os = f.OutlineSettings
                    os.OutlineSize = 0
                    os.OutlineColor = ESP_TEXT_CLEAR
                    f.OutlineSettings = os
                end)
            end
            pcall(function() textWidget:SetFont(f) end)
            pcall(function() textWidget.Font = f end)
        end
        if textWidget.SetShadowOffset then
            pcall(function() textWidget:SetShadowOffset(g_UXOfficial_ESPV2(0.0,0.0)) end)
        end
        if textWidget.SetShadowColorAndOpacity then
            pcall(function() textWidget:SetShadowColorAndOpacity(ESP_TEXT_CLEAR) end)
        end
    end)
end

-- ESP text color made by @UXOfficial
local function g_UXOfficial_ESPSetTextColor(textWidget, color)
    if not g_UXOfficial_ESPValid(textWidget) or not color then return end
    local applied = false
    pcall(function()
        local sc = textWidget.ColorAndOpacity or g_UXOfficial_ShotESP.TemplateColorAndOpacity or (SlateColor and SlateColor())
        if sc then
            sc.SpecifiedColor = color
            pcall(function() sc.ColorUseRule = 0 end)
            local check = sc.SpecifiedColor
            if check and tonumber(check.A) and tonumber(check.A) > 0 then
                textWidget:SetColorAndOpacity(sc)
                pcall(function() textWidget.ColorAndOpacity = sc end)
                applied = true
            end
        end
    end)
    if not applied then
        pcall(function() textWidget:SetColorAndOpacity(color) end)
    end
    pcall(function() if textWidget.SetOpacity then textWidget:SetOpacity(1.0) end end)
    pcall(function() if textWidget.SetRenderOpacity then textWidget:SetRenderOpacity(1.0) end end)
end

-- ESP line widget made by @UXOfficial
local function g_UXOfficial_ESPCreateLine(color,parent)
    local canvas = parent or g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local budget = g_UXOfficial_ShotESP.BuildRemaining
    if budget ~= nil then
        if budget <= 0 then return nil end
        g_UXOfficial_ShotESP.BuildRemaining = budget - 1
    end
    local pooled=canvas==g_UXOfficial_ShotESP.Canvas and ESPWidgetPool.Take(ESPWidgetPool.V2,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_UXOfficial_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_UXOfficial_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot}
    if canvas==g_UXOfficial_ShotESP.Canvas then ESPWidgetPool.Tag(ESPWidgetPool.V2,"Line",canvas,data) end
    return data
end

-- ESP line made by @UXOfficial
local function g_UXOfficial_ESPDrawLine(data, x1, y1, x2, y2, thickness)
    if not data or not data.Widget or not data.Slot then return false end
    local dx, dy = x2-x1, y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
        return false
    end
    local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
    local unchanged=data.Visible==true and data.X1 and
        math.abs(data.X1-x1)<0.25 and math.abs(data.Y1-y1)<0.25 and
        math.abs(data.X2-x2)<0.25 and math.abs(data.Y2-y2)<0.25 and
        math.abs((data.Thickness or 0)-thickness)<0.05
    if unchanged then return true end
    -- Reuse native transform values after the first draw. Older bindings
    -- that reject mutable structs fall back once to the original setter path.
    local setterOK=pcall(function()
        if data.VectorReuseDisabled then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_UXOfficial_ESPV2(len, thickness))
        else
            data.PosVec=data.PosVec or g_UXOfficial_ESPV2(x1, y1 - thickness*0.5)
            data.SizeVec=data.SizeVec or g_UXOfficial_ESPV2(len, thickness)
            data.PosVec.X=x1;data.PosVec.Y=y1-thickness*0.5
            data.SizeVec.X=len;data.SizeVec.Y=thickness
            data.Slot:SetPosition(data.PosVec)
            data.Slot:SetSize(data.SizeVec)
        end
        data.Widget:SetRenderAngle(angle)
        if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if not setterOK and not data.VectorReuseDisabled then
        data.VectorReuseDisabled=true;data.PosVec=nil;data.SizeVec=nil
        setterOK=pcall(function()
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_UXOfficial_ESPV2(len, thickness))
            data.Widget:SetRenderAngle(angle)
            if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
        end)
    end
    if not setterOK then data.Broken=true return false end
    data.Broken=false
    data.X1,data.Y1,data.X2,data.Y2,data.Thickness=x1,y1,x2,y2,thickness
    data.Visible=true
    return true
end

-- ESP widget hide made by @UXOfficial
local function g_UXOfficial_ESPHide(data)
    if data and data.Visible~=false and data.Widget then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        if not ok then data.Broken=true end
        data.Visible=false
    end
end

local function g_UXOfficial_ESPDestroyGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end
end

-- Check native widget validity at discovery cadence; failed setters mark a
-- piece broken immediately. This avoids an IsValid bridge call per piece/frame.
local function g_UXOfficial_ESPGroupHealthy(group)
    if not group then return false end
    local now = g_UXOfficial_ShotESP.Now
    local validate = not group.ValidatedAt or now < group.ValidatedAt or now-group.ValidatedAt >= 0.35
    for _, data in ipairs(group) do
        if data.Broken or (validate and not g_UXOfficial_ESPValid(data.Widget)) then return false end
    end
    if validate then group.ValidatedAt = now end
    return true
end

-- Keep partial groups across ticks; budgeted creation prevents first-visibility spikes.
local function g_UXOfficial_ESPLineGroup(registry, key, count, color, parent)
    local group = registry[key]
    if group and not g_UXOfficial_ESPGroupHealthy(group) then
        g_UXOfficial_ESPDestroyGroup(group)
        group = nil
    end
    if not group or #group > count then
        g_UXOfficial_ESPDestroyGroup(group)
        group = {}
        registry[key] = group
    end
    while #group < count do
        local data = g_UXOfficial_ESPCreateLine(color, parent)
        if not data then return nil end
        group[#group + 1] = data
        g_UXOfficial_ESPHide(data)
    end
    return group
end

-- Existing geometry and widgets are reused. Stable identity performs no native
-- color setters; failed brush assignments remain eligible for retry.
local function g_UXOfficial_ESPApplyGroupTheme(group,theme,kind)
    if not group or group.ThemeKey==theme.Key then return end
    local ok=pcall(function()
        for i,piece in ipairs(group) do
            local color=theme.Main
            if kind=="Header" then
                if i>=23 then color=theme.Background
                elseif i>=9 and i<=12 then color=theme.Light end
            elseif kind=="Arcs" then
                if i>=11 and i<=20 then color=theme.Light end
            elseif kind=="Footer" then
                if i<=4 then color=theme.Light end
            elseif kind=="Health" then
                if i==1 then color=theme.Background
                elseif i>=10 then color=theme.Light
                else color=theme.Empty end
            end
            piece.Widget:SetBrushColor(color)
        end
    end)
    if ok then group.ThemeKey=theme.Key end
end

local function g_UXOfficial_ESPHideGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_UXOfficial_ESPHide(data) end
end

local function g_UXOfficial_ESPHideDetailedEnemy(key)
    g_UXOfficial_ESPHide(g_UXOfficial_ShotESP.Lines[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Boxes[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.HealthBars[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Skeletons[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Headers[key])
    local decor=g_UXOfficial_ShotESP.Decorations[key]
    if decor and decor.Visible~=false then pcall(function() decor.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) decor.Visible=false end
end

local g_UXOfficial_ESPHealthRatio

local function g_UXOfficial_ESPSetGroupVisible(group,visible)
    if not group or group.GroupVisible==visible then return end
    for _,data in ipairs(group) do
        if visible then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            data.Visible=true
        else g_UXOfficial_ESPHide(data) end
    end
    group.GroupVisible=visible
end

local function g_UXOfficial_ESPCreateDecorationRoot(poolKind)
    local canvas=g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    poolKind=poolKind or "Decor"
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,poolKind,canvas)
    if pooled then
        local ok=pcall(function()
            pooled.Slot:SetZOrder(poolKind=="Header" and 30 or 29)
            pooled.Widget:SetRenderScale(g_UXOfficial_ESPV2(1.0,1.0))
            pooled.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        if ok then pooled.Visible=true;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local root=nil
    pcall(function() root=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_UXOfficial_ESPValid(root) then return nil end
    local slot=nil
    pcall(function() slot=canvas:AddChildToCanvas(root) end)
    if not slot then g_UXOfficial_ESPDestroyWidgetData({Widget=root}) return nil end
    pcall(function()
        slot:SetAutoSize(false)
        slot:SetSize(g_UXOfficial_ESPV2(1000.0,1400.0))
        slot:SetZOrder(29)
        root:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.0,0.0))
        root:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,poolKind,canvas,{Widget=root,Slot=slot,Groups={},Visible=true})
end

local function g_UXOfficial_ESPDecorGroup(data,name,count,color)
    return g_UXOfficial_ESPLineGroup(data.Groups,name,count,color,data.Widget)
end


local function g_UXOfficial_ESPBuildArcs(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Arcs",26,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    -- APEX star-diamond reticle: layered facets and four sharp crown accents.
    -- No rounded geometry; the silhouette stays crisp at every render scale.
    local cx,cy,hw,hh=500.0,385.0,268.0,180.0
    local top={cx,cy-hh}; local right={cx+hw,cy}
    local bottom={cx,cy+hh}; local left={cx-hw,cy}
    local tr={cx+hw*0.50,cy-hh*0.50}; local br={cx+hw*0.50,cy+hh*0.50}
    local bl={cx-hw*0.50,cy+hh*0.50}; local tl={cx-hw*0.50,cy-hh*0.50}
    local innerTop={cx,cy-hh*0.70}; local innerRight={cx+hw*0.70,cy}
    local innerBottom={cx,cy+hh*0.70}; local innerLeft={cx-hw*0.70,cy}
    local itr={cx+hw*0.35,cy-hh*0.35}; local ibr={cx+hw*0.35,cy+hh*0.35}
    local ibl={cx-hw*0.35,cy+hh*0.35}; local itl={cx-hw*0.35,cy-hh*0.35}
    local lines={
      {top[1],top[2],tr[1],tr[2]},{tr[1],tr[2],right[1],right[2]},
      {right[1],right[2],br[1],br[2]},{br[1],br[2],bottom[1],bottom[2]},
      {bottom[1],bottom[2],bl[1],bl[2]},{bl[1],bl[2],left[1],left[2]},
      {left[1],left[2],tl[1],tl[2]},{tl[1],tl[2],top[1],top[2]},
      {innerTop[1],innerTop[2],itr[1],itr[2]},{itr[1],itr[2],innerRight[1],innerRight[2]},
      {innerRight[1],innerRight[2],ibr[1],ibr[2]},{ibr[1],ibr[2],innerBottom[1],innerBottom[2]},
      {innerBottom[1],innerBottom[2],ibl[1],ibl[2]},{ibl[1],ibl[2],innerLeft[1],innerLeft[2]},
      {innerLeft[1],innerLeft[2],itl[1],itl[2]},{itl[1],itl[2],innerTop[1],innerTop[2]},
      {cx-15,cy-hh-4,cx,cy-hh-22},{cx,cy-hh-22,cx+15,cy-hh-4},
      {cx-15,cy+hh+4,cx,cy+hh+22},{cx,cy+hh+22,cx+15,cy+hh+4},
      {cx-hw-4,cy-15,cx-hw-22,cy},{cx-hw-22,cy,cx-hw-4,cy+15},
      {cx+hw+4,cy-15,cx+hw+22,cy},{cx+hw+22,cy,cx+hw+4,cy+15},
      {cx-20,cy,cx-8,cy},{cx+8,cy,cx+20,cy}
    }
    for i,line in ipairs(lines) do
        if i>=17 then pcall(function() group[i].Widget:SetBrushColor(ESP_WHITE) end) end
        g_UXOfficial_ESPDrawLine(group[i],line[1],line[2],line[3],line[4],i<=8 and 3.2 or (i<=16 and 1.5 or 1.8))
    end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_UXOfficial_ESPBuildHealth(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Health",11,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    -- Compact horizontal health bar, centered just above the character's head.
    -- The eight short segments keep it readable without covering the name plate.
    local cx,barY,barW,barH=500.0,120.0,240.0,9.0
    local left,right=cx-barW*.5,cx+barW*.5
    pcall(function()
        for i=1,11 do group[i].Widget:SetBrushColor(ESP_REAL) end
    end)
    g_UXOfficial_ESPDrawLine(group[1],left,barY,right,barY,barH+2.0)
    local segmentW=barW/8
    for i=1,8 do
        local x1=left+(i-1)*segmentW+1.5
        local x2=left+i*segmentW-1.5
        g_UXOfficial_ESPDrawLine(group[i+1],x1,barY,x2,barY,barH)
    end
    g_UXOfficial_ESPDrawLine(group[10],left,barY-barH*.5-2.0,right,barY-barH*.5-2.0,1.2)
    g_UXOfficial_ESPDrawLine(group[11],left,barY+barH*.5+2.0,right,barY+barH*.5+2.0,1.2)
    group.Built=true group.GroupVisible=true group.Filled=-1
    return group
end

local function g_UXOfficial_ESPBuildFooter(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Footer",6,ESP_WHITE)
    if not group then return nil end
    if group.Built then return group end
    local cx,y,w=500.0,1243.0,394.0
    local s={{cx-w*.5,y,cx-w*.5+18,y-10},{cx-w*.5+18,y-10,cx-w*.5+36,y},
      {cx+w*.5-36,y,cx+w*.5-18,y-10},{cx+w*.5-18,y-10,cx+w*.5,y},
      {cx-15,y,cx,y-9},{cx,y-9,cx+15,y}}
    for i,v in ipairs(s) do pcall(function() group[i].Widget:SetBrushColor(i>=5 and ESP_REAL or ESP_WHITE) end) g_UXOfficial_ESPDrawLine(group[i],v[1],v[2],v[3],v[4],i>=5 and 2.8 or 2.0) end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_UXOfficial_ESPUpdateDecoration(key,character,head,feet,opt,stage,isBot)
    local enabled=opt.Name or opt.Box or opt.Health or opt.Distance
    local data=g_UXOfficial_ShotESP.Decorations[key]
    if not enabled or not head or not feet then
        if data and data.Visible~=false then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.Visible=false end
        return
    end
    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        g_UXOfficial_ESPDestroyWidgetData(data)
        data=g_UXOfficial_ESPCreateDecorationRoot()
        g_UXOfficial_ShotESP.Decorations[key]=data
    end
    if not data then return end
    local h=math.abs(feet.Y-head.Y)
    if h<8 then return end
    local scale=h/1000.0
    local x,y=head.X-500.0*scale,head.Y-200.0*scale
    local moved=not data.X or math.abs(data.X-x)>=.25 or math.abs(data.Y-y)>=.25
    local scaled=not data.Scale or math.abs(data.Scale-scale)>=.001
    if moved then
        local ok=pcall(function() data.Slot:SetPosition(g_UXOfficial_ESPV2(x,y)) end)
        if ok then data.X,data.Y=x,y end
    end
    if scaled then
        local ok=pcall(function() data.Widget:SetRenderScale(g_UXOfficial_ESPV2(scale,scale)) end)
        if ok then data.Scale=scale else data.Scale=nil end
    end
    if data.Visible~=true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end
    -- Header: handled by ESPUpdateHeaderFrame (screen-space, dynamic width) — hide DecorationRoot version
    if data.Groups.Header then g_UXOfficial_ESPSetGroupVisible(data.Groups.Header, false) end
    local theme=g_UXOfficial_ESPTheme(isBot)
    local arcs=data.Groups.Arcs
    if opt.Box then arcs=g_UXOfficial_ESPBuildArcs(data) end
    if arcs then g_UXOfficial_ESPApplyGroupTheme(arcs,theme,"Arcs") end
    g_UXOfficial_ESPSetGroupVisible(arcs,opt.Box==true)
    local health=data.Groups.Health
    if opt.Health then health=g_UXOfficial_ESPBuildHealth(data) end
    local healthTypeChanged=health and health.ThemeKey~=theme.Key
    if health then g_UXOfficial_ESPApplyGroupTheme(health,theme,"Health") end
    g_UXOfficial_ESPSetGroupVisible(health,opt.Health==true)
    if health and opt.Health then
        local ratio=g_UXOfficial_ESPHealthRatio(character)
        local filled=math.ceil(ratio*8-.001)
        -- Low health is red, medium health is yellow, and high/full health is green.
        local healthColor
        if ratio<=0.30 then
            healthColor=g_UXOfficial_ESPColor(1.0,0.30,0.22,1.0)
        elseif ratio<=0.70 then
            healthColor=g_UXOfficial_ESPColor(1.0,0.90,0.42,1.0)
        else
            healthColor=g_UXOfficial_ESPColor(1.0,0.72,0.20,1.0)
        end
        if health.Filled~=filled or health.HealthColorKey~= (ratio<=0.30 and "red" or (ratio<=0.70 and "yellow" or "green")) or healthTypeChanged then
            local ok=pcall(function()
                for i=1,8 do health[i+1].Widget:SetBrushColor(i<=filled and healthColor or g_UXOfficial_ESPColor(0.035,0.04,0.05,0.88)) end
                health[1].Widget:SetBrushColor(g_UXOfficial_ESPColor(0.005,0.007,0.010,0.95))
                health[10].Widget:SetBrushColor(healthColor)
                health[11].Widget:SetBrushColor(healthColor)
            end)
            if ok then
                health.Filled=filled
                health.HealthColorKey=ratio<=0.30 and "red" or (ratio<=0.70 and "yellow" or "green")
            end
        end
    end
    local footer=data.Groups.Footer
    if opt.Distance then footer=g_UXOfficial_ESPBuildFooter(data) end
    if footer then g_UXOfficial_ESPApplyGroupTheme(footer,theme,"Footer") end
    g_UXOfficial_ESPSetGroupVisible(footer,opt.Distance==true)
end

local function g_UXOfficial_ESPUpdateHeaderFrame(key,head,feet,enabled,isBot)
    local group=g_UXOfficial_ShotESP.Headers[key]
    if not enabled or not head or not feet then g_UXOfficial_ESPHideGroup(group) return end
    local h=math.abs(feet.Y-head.Y)
    -- Compact distance scaling.  The bottom edge stays above the head and all
    -- height growth happens upward, so zooming never pushes the plate onto the body.
    local w=math.max(68.0,math.min(232.0,h*0.315))
    local cached=g_UXOfficial_ShotESP.Names[key] and g_UXOfficial_ShotESP.Names[key].CachedName or ""
    w=math.max(w,math.min(232.0,28.0+#tostring(cached)*6.0))
    local hh=math.max(18.0,math.min(48.0,h*0.070))
    local headGap=math.max(4.0,math.min(10.0,h*0.025))
    local cx=head.X
    local b=head.Y-headGap
    local t=b-hh
    local cy=(t+b)*0.5
    local l,r=cx-w*0.5,cx+w*0.5
    local cut=hh*0.28
    -- 25 frame/background widgets + 8 horizontal fill bands per corner.
    -- The bands approximate true triangles without using rotated rectangles,
    -- which were the source of the original black corner leakage.
    local root = g_UXOfficial_ShotESP.HeaderRoots[key]
    if not root or not g_UXOfficial_ESPValid(root.Widget) then
        g_UXOfficial_ESPDestroyGroup(group)
        g_UXOfficial_ShotESP.Headers[key] = nil
        group = nil
        g_UXOfficial_ESPDestroyWidgetData(root)
        root = g_UXOfficial_ESPCreateDecorationRoot("Header")
        g_UXOfficial_ShotESP.HeaderRoots[key] = root
        if not root then return end
        group=root.Groups.__Header
        root.Groups.__Header=nil
        g_UXOfficial_ShotESP.Headers[key]=group
        pcall(function() root.Slot:SetZOrder(30) end)
    end
    -- Move 57 header pieces with one parent slot. Width/height changes still
    -- rebuild the exact original geometry with constant stroke thickness.
    local rootY = b
    local moved = not root.X or math.abs(root.X-cx) >= 0.25 or math.abs(root.Y-rootY) >= 0.25
    if moved then
        local ok = pcall(function() root.Slot:SetPosition(g_UXOfficial_ESPV2(cx,rootY)) end)
        if ok then root.X,root.Y = cx,rootY end
    end
    local theme=g_UXOfficial_ESPTheme(isBot)
    local ready = group and #group == 57
    if ready then g_UXOfficial_ESPApplyGroupTheme(group,theme,"Header") end
    if ready and group.Width and math.abs(group.Width-w) < 0.25 and math.abs(group.Height-hh) < 0.25 then
        local healthy = g_UXOfficial_ESPGroupHealthy(group)
        if healthy then
            for _, piece in ipairs(group) do
                if piece.Drawn then
                    if piece.Visible ~= true then
                        local ok = pcall(function() piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        if ok then piece.Visible = true end
                    end
                else g_UXOfficial_ESPHide(piece) end
            end
            return
        end
    end
    group=g_UXOfficial_ESPLineGroup(g_UXOfficial_ShotESP.Headers,key,57,ESP_REAL,root.Widget)
    if not group then return end
    cx, b, t, cy = 0.0, 0.0, -hh, -hh*0.5
    l, r = -w*0.5, w*0.5
    local seg={{l+cut,t,r-cut,t},{r-cut,t,r,t+cut},{r,t+cut,r,b-cut},{r,b-cut,r-cut,b},{r-cut,b,l+cut,b},{l+cut,b,l,b-cut},{l,b-cut,l,t+cut},{l,t+cut,l+cut,t}}
    if not group.HeaderStyled then
        local ok=pcall(function() for i=23,57 do group[i].Slot:SetZOrder(0) end end)
        if ok then group.HeaderStyled=true end
    end
    g_UXOfficial_ESPApplyGroupTheme(group,theme,"Header")
    -- octagon border
    for i,s in ipairs(seg) do g_UXOfficial_ESPDrawLine(group[i],s[1],s[2],s[3],s[4],2.0) end
    -- white inner accent lines on top/bottom edges
    g_UXOfficial_ESPDrawLine(group[9],l+cut*1.05,t,l+w*0.16,t,1.25)
    g_UXOfficial_ESPDrawLine(group[10],r-w*0.16,t,r-cut*1.05,t,1.25)
    g_UXOfficial_ESPDrawLine(group[11],l+cut*1.05,b,l+w*0.16,b,1.25)
    g_UXOfficial_ESPDrawLine(group[12],r-w*0.16,b,r-cut*1.05,b,1.25)
    -- bottom spike
    g_UXOfficial_ESPDrawLine(group[13],cx-cut*0.7,b,cx,b+cut,2.0)
    g_UXOfficial_ESPDrawLine(group[14],cx,b+cut,cx+cut*0.7,b,2.0)
    -- chevrons (side arrows)
    local co=cut*0.70
    g_UXOfficial_ESPDrawLine(group[15],l-co*1.9,cy,l-co*1.25,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[16],l-co*1.9,cy,l-co*1.25,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[17],r+co*1.9,cy,r+co*1.25,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[18],r+co*1.9,cy,r+co*1.25,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[19],l-co*2.8,cy,l-co*2.15,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[20],l-co*2.8,cy,l-co*2.15,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[21],r+co*2.8,cy,r+co*2.15,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[22],r+co*2.8,cy,r+co*2.15,cy+co,2.2)
    -- background: center + left strip + right strip (3-part fill of octagon interior)
    g_UXOfficial_ESPDrawLine(group[23],l+cut,cy,r-cut,cy,hh)
    g_UXOfficial_ESPDrawLine(group[24],l,cy,l+cut,cy,hh-2*cut)
    g_UXOfficial_ESPDrawLine(group[25],r-cut,cy,r,cy,hh-2*cut)
    -- Fill each missing corner triangle with horizontal stepped bands.  Every
    -- band starts inside the diagonal, so black cannot cross the red border.
    local cornerSteps=8
    local bandH=cut/cornerSteps
    for i=1,cornerSteps do
        local inset=(i-1)*bandH
        local topY=t+(i-0.5)*bandH
        local bottomY=b-(i-0.5)*bandH
        local leftStart=l+cut-inset
        local rightEnd=r-cut+inset

        if inset>0.5 then
            g_UXOfficial_ESPDrawLine(group[25+i],leftStart,topY,l+cut+0.5,topY,bandH)
            g_UXOfficial_ESPDrawLine(group[33+i],r-cut-0.5,topY,rightEnd,topY,bandH)
            g_UXOfficial_ESPDrawLine(group[41+i],leftStart,bottomY,l+cut+0.5,bottomY,bandH)
            g_UXOfficial_ESPDrawLine(group[49+i],r-cut-0.5,bottomY,rightEnd,bottomY,bandH)
        else
            g_UXOfficial_ESPHide(group[25+i])
            g_UXOfficial_ESPHide(group[33+i])
            g_UXOfficial_ESPHide(group[41+i])
            g_UXOfficial_ESPHide(group[49+i])
        end
    end
    group.Width, group.Height = w, hh
    for _, piece in ipairs(group) do piece.Drawn = piece.Visible == true end
end



g_UXOfficial_ESPHealthRatio = function(character)
    local hp, maxHp = nil, nil
    pcall(function()
        hp = character.Health or character.HP or character.CurrentHealth
        maxHp = character.HealthMax or character.MaxHealth or character.MaxHP
        if not tonumber(hp) and character.GetHealth then hp=character:GetHealth() end
        if not tonumber(maxHp) and character.GetMaxHealth then maxHp=character:GetMaxHealth() end
    end)
    hp, maxHp = tonumber(hp), tonumber(maxHp)
    if not hp or not maxHp or maxHp <= 0 then return 1.0 end
    return math.max(0.0,math.min(1.0,hp/maxHp))
end




local g_UXOfficial_ESPBones = {
    head={"Head","head","head_01"}, neck={"neck_01","Neck","neck"},
    chest={"spine_03","Spine3","chest","Chest"}, spine={"spine_02","Spine2","spine"}, pelvis={"pelvis","Pelvis"},
    ls={"clavicle_l","upperarm_l","UpperArm_L"}, le={"lowerarm_l","LowerArm_L"}, lw={"hand_l","Hand_L"},
    rs={"clavicle_r","upperarm_r","UpperArm_R"}, re={"lowerarm_r","LowerArm_R"}, rw={"hand_r","Hand_R"},
    lh={"thigh_l","Thigh_L","hip_l"}, lk={"calf_l","Calf_L","knee_l"}, la={"foot_l","Foot_L"},
    rh={"thigh_r","Thigh_R","hip_r"}, rk={"calf_r","Calf_R","knee_r"}, ra={"foot_r","Foot_R"}
}
-- Full-length articulated skeleton: head, torso, shoulders, arms, pelvis and legs.
local g_UXOfficial_ESPBoneLinks={{"head","neck"},{"neck","chest"},{"chest","spine"},{"spine","pelvis"},{"chest","ls"},{"ls","le"},{"le","lw"},{"chest","rs"},{"rs","re"},{"re","rw"},{"pelvis","lh"},{"lh","lk"},{"lk","la"},{"pelvis","rh"},{"rh","rk"},{"rk","ra"}}

-- Cache only the bone-name lookup; world positions and camera projections remain fresh.
local function g_UXOfficial_ESPBoneScreen(pc, mesh, id, names, cache)
    local cached = cache[id]
    if cached then
        local ok, loc = pcall(function()
            if mesh.GetSocketLocation then return mesh:GetSocketLocation(cached)
            elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(cached) end
        end)
        if ok and loc and tonumber(loc.X) then return g_UXOfficial_ESPProject(pc,loc) end
        cache[id] = nil
    end
    for _, name in ipairs(names) do
        local ok, loc = pcall(function()
            local exists = nil
            if mesh.DoesSocketExist then exists = mesh:DoesSocketExist(name)
            elseif mesh.GetBoneIndex then exists = (tonumber(mesh:GetBoneIndex(name)) or -1) >= 0 end
            if exists ~= false then
                if mesh.GetSocketLocation then return mesh:GetSocketLocation(name)
                elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(name) end
            end
        end)
        if ok and loc and tonumber(loc.X) then
            cache[id] = name
            return g_UXOfficial_ESPProject(pc,loc)
        end
    end
    return nil
end

local function g_UXOfficial_ESPUpdateSkeleton(key, character, pc, enabled, isBot, visibilityColor)
    local group = g_UXOfficial_ShotESP.Skeletons[key]
    if not enabled then g_UXOfficial_ESPHideGroup(group) return end
    local mesh = nil
    pcall(function() mesh=character.Mesh or (character.GetMesh and character:GetMesh()) end)
    if not g_UXOfficial_ESPValid(mesh) then g_UXOfficial_ESPHideGroup(group) return end
    if g_UXOfficial_ShotESP.BoneMeshes[key] ~= mesh then
        g_UXOfficial_ShotESP.BoneMeshes[key] = mesh
        g_UXOfficial_ShotESP.BoneNameCache[key] = {}
        g_UXOfficial_ShotESP.BonePoints[key] = {}
    end
    local points = g_UXOfficial_ShotESP.BonePoints[key]
    local cache = g_UXOfficial_ShotESP.BoneNameCache[key]
    local theme=g_UXOfficial_ESPTheme(isBot)
    local baseCount=#g_UXOfficial_ESPBoneLinks
    local detailCount=60
    group = g_UXOfficial_ESPLineGroup(g_UXOfficial_ShotESP.Skeletons,key,baseCount+detailCount,ESP_SKELETON_YELLOW)
    if not group then return end
    local skeletonColor = visibilityColor or ESP_SKELETON_YELLOW
    g_UXOfficial_ESPApplyGroupTheme(group,{Key=theme.Key.."_MR_FAHAD",Main=skeletonColor,Light=skeletonColor,Background=theme.Background,Empty=theme.Empty},"Skeleton")
    for id, names in pairs(g_UXOfficial_ESPBones) do
        points[id] = g_UXOfficial_ESPBoneScreen(pc,mesh,id,names,cache)
    end
    local ankle = points.la or points.ra
    local skeletonH = (points.head and ankle) and math.abs(ankle.Y-points.head.Y) or 360.0
    local thickness = math.max(1.15,math.min(3.0,skeletonH*0.00325))
    local spectrum={g_UXOfficial_ESPColor(0.20,1.0,0.82,1.0),
        g_UXOfficial_ESPColor(0.10,0.72,1.0,1.0),
        g_UXOfficial_ESPColor(0.42,0.38,1.0,1.0),
        g_UXOfficial_ESPColor(0.82,0.28,1.0,1.0),
        g_UXOfficial_ESPColor(1.0,0.32,0.58,1.0),
        g_UXOfficial_ESPColor(1.0,0.68,0.20,1.0),
        g_UXOfficial_ESPColor(0.92,1.0,0.34,1.0)}
    local phase=math.floor((os.clock and os.clock() or 0)*7.0)
    for i=1,baseCount+detailCount do
        local color=spectrum[((i+phase-1)%#spectrum)+1]
        local piece=group[i]
        if piece and piece.Widget and piece.SpectrumPhase~=phase then
            pcall(function() piece.Widget:SetBrushColor(color) end)
            piece.SpectrumPhase=phase
        end
    end
    for i, link in ipairs(g_UXOfficial_ESPBoneLinks) do
        local a, b = points[link[1]], points[link[2]]
        if a and b then g_UXOfficial_ESPDrawLine(group[i],a.X,a.Y,b.X,b.Y,thickness)
        else g_UXOfficial_ESPHide(group[i]) end
    end
    local extra={}
    local function add(x1,y1,x2,y2,w)
        extra[#extra+1]={x1,y1,x2,y2,w or thickness}
    end
    local function diamond(cx,cy,rx,ry,w)
        add(cx,cy-ry,cx+rx,cy,w)
        add(cx+rx,cy,cx,cy+ry,w)
        add(cx,cy+ry,cx-rx,cy,w)
        add(cx-rx,cy,cx,cy-ry,w)
    end
    local function triangle(ax,ay,bx,by,cx,cy,w)
        add(ax,ay,bx,by,w); add(bx,by,cx,cy,w); add(cx,cy,ax,ay,w)
    end
        -- V14 ECLIPSE: star-core chest, layered shoulder armor and articulated limb plating.
    local chest=points.chest or points.spine
    if chest then
        local r=math.max(9.0,math.min(27.0,skeletonH*0.049))
        diamond(chest.X,chest.Y,r*0.78,r*0.88,thickness*1.45)
        triangle(chest.X,chest.Y-r*0.92,chest.X-r*0.92,chest.Y+r*0.58,
                 chest.X+r*0.92,chest.Y+r*0.58,thickness*1.0)
        add(chest.X-r*0.72,chest.Y,chest.X+r*0.72,chest.Y,thickness*0.78)
        add(chest.X,chest.Y-r*0.78,chest.X,chest.Y+r*0.74,thickness*0.78)
        add(chest.X-r*0.38,chest.Y-r*0.20,chest.X,chest.Y+r*0.38,thickness*0.95)
        add(chest.X,chest.Y+r*0.38,chest.X+r*0.38,chest.Y-r*0.20,thickness*0.95)
    end
    -- Double-layer shoulder pauldrons with a pointed outer edge.
    for _,side in ipairs({-1,1}) do
        local s=side<0 and points.ls or points.rs
        local e=side<0 and points.le or points.re
        local w=side<0 and points.lw or points.rw
        if s then
            local r=math.max(7.0,math.min(18.0,skeletonH*0.031))
            local aX,aY=s.X-side*r*0.45,s.Y-r*0.55
            local bX,bY=s.X+side*r*1.75,s.Y-r*0.88
            local cX,cY=s.X+side*r*1.28,s.Y+r*0.62
            triangle(aX,aY,bX,bY,cX,cY,thickness*1.12)
            add(aX,aY,cX,cY,thickness*0.78)
            add(s.X,s.Y,bX,bY,thickness*0.82)
        end
        if e then
            local r=math.max(4.0,skeletonH*0.012)
            diamond(e.X,e.Y,r,r*1.22,thickness*0.9)
            add(e.X-r*1.5,e.Y,e.X+r*1.5,e.Y,thickness*0.7)
        end
        if w and e then add(e.X,e.Y,w.X,w.Y,thickness*0.72) end
    end
    -- Six-sided waist shield with a split central ridge.
    local pelvis=points.pelvis
    if pelvis then
        local r=math.max(9.0,math.min(21.0,skeletonH*0.036))
        local q={{-r,0},{-r*.55,-r*.62},{r*.55,-r*.62},{r,0},{r*.55,r*.62},{-r*.55,r*.62}}
        for i=1,#q do local a=q[i];local b=q[(i%#q)+1];add(pelvis.X+a[1],pelvis.Y+a[2],pelvis.X+b[1],pelvis.Y+b[2],thickness*0.95) end
        add(pelvis.X-r*.52,pelvis.Y,pelvis.X,pelvis.Y+r*.42,thickness*0.82)
        add(pelvis.X,pelvis.Y+r*.42,pelvis.X+r*.52,pelvis.Y,thickness*0.82)
    end
    -- Diamond knee caps, paired shin rails and a sharp head crown.
    for _,k in ipairs({points.lk,points.rk}) do
        if k then
            local r=math.max(4.5,skeletonH*0.013)
            diamond(k.X,k.Y,r,r*1.25,thickness*1.0)
            add(k.X-r*1.45,k.Y,k.X+r*1.45,k.Y,thickness*0.72)
        end
    end
    for _,leg in ipairs({{points.lk,points.la},{points.rk,points.ra}}) do
        local k,a=leg[1],leg[2]
        if k and a then
            local dx,dy=a.X-k.X,a.Y-k.Y
            local len=math.max(1.0,math.sqrt(dx*dx+dy*dy))
            local ox,oy=-dy/len*3.0,dx/len*3.0
            add(k.X+ox,k.Y+oy,a.X+ox,a.Y+oy,thickness*0.68)
            add(k.X-ox,k.Y-oy,a.X-ox,a.Y-oy,thickness*0.68)
        end
    end
    if points.head then
        local r=math.max(4.5,math.min(11.0,skeletonH*0.020))
        add(points.head.X-r,points.head.Y-r,points.head.X,points.head.Y-r*1.9,thickness)
        add(points.head.X,points.head.Y-r*1.9,points.head.X+r,points.head.Y-r,thickness)
        add(points.head.X-r,points.head.Y-r,points.head.X+r,points.head.Y-r,thickness*0.72)
    end
    for j=1,detailCount do
        local line=extra[j]
        local idx=baseCount+j
        if line then g_UXOfficial_ESPDrawLine(group[idx],line[1],line[2],line[3],line[4],line[5])
        else g_UXOfficial_ESPHide(group[idx]) end
    end
end
-- ESP enemy name widget made by @UXOfficial
local function g_UXOfficial_ESPCreateNameTag(isBot)
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,"NameV2",canvas)
    if pooled then
        local theme=g_UXOfficial_ESPTheme(isBot)
        g_UXOfficial_ESPSetTextColor(pooled.Text,theme.Text)
        g_UXOfficial_ESPSetTextColor(pooled.DistanceText,theme.Text)
        g_UXOfficial_ESPSetFont(pooled.Text,tonumber(_G.g_UXOfficial_UXOfficialShotESP.NameFontSize) or 16,0)
        g_UXOfficial_ESPSetFont(pooled.DistanceText,tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 20,0)
        pooled.IsBot=isBot;pooled.ContainerVisible=false
        if pooled then return pooled end
    end

    local container, nameText, distanceText, namePlate, badgeText = nil, nil, nil, nil, nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_UXOfficial_ESPValid(container) then return nil end
    -- APEX target plate: compact obsidian glass with solar / glacier identity.
    pcall(function() namePlate = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    pcall(function() badgeText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if not g_UXOfficial_ESPValid(nameText) or not g_UXOfficial_ESPValid(distanceText) then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        if g_UXOfficial_ESPValid(namePlate) then
            namePlate:SetBrushColor(isBot and g_UXOfficial_ESPColor(0.012,0.042,0.075,0.96) or g_UXOfficial_ESPColor(0.055,0.026,0.012,0.96))
            namePlate:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
        if g_UXOfficial_ESPValid(badgeText) then
            badgeText:SetText(isBot and "B" or "D")
            badgeText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if badgeText.SetJustification then badgeText:SetJustification(1) end
        end
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if nameText.SetRenderTransformPivot then nameText:SetRenderTransformPivot(g_UXOfficial_ESPV2(.5,.5)) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        if distanceText.SetRenderTransformPivot then distanceText:SetRenderTransformPivot(g_UXOfficial_ESPV2(.5,.5)) end
    end)

    local theme=g_UXOfficial_ESPTheme(isBot)
    -- Crisp ivory typography with team-colored metadata.
    g_UXOfficial_ESPSetTextColor(nameText, g_UXOfficial_ESPColor(1.0,0.97,0.88,1.0))
    g_UXOfficial_ESPSetTextColor(distanceText, theme.Text)
    g_UXOfficial_ESPSetTextColor(badgeText, theme.Light)
    g_UXOfficial_ESPSetFont(badgeText, 11, 0)
    g_UXOfficial_ESPSetFont(nameText, math.min(12,tonumber(_G.g_UXOfficial_UXOfficialShotESP.NameFontSize) or 12), 0)
    -- Distance labels are intentionally borderless; the larger glyphs provide clarity.
    g_UXOfficial_ESPSetFont(distanceText, math.min(14,tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 14), 0)
    local nameSlot, distanceSlot, mainSlot, plateSlot, badgeSlot = nil, nil, nil, nil, nil
    if g_UXOfficial_ESPValid(namePlate) then pcall(function() plateSlot = container:AddChildToCanvas(namePlate) end) end
    if g_UXOfficial_ESPValid(badgeText) then pcall(function() badgeSlot = container:AddChildToCanvas(badgeText) end) end
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    if not nameSlot or not distanceSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)
    if not mainSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetAlignment(g_UXOfficial_ESPV2(0.0, 0.0))
        mainSlot:SetZOrder(65)
        if plateSlot then
            plateSlot:SetAutoSize(false)
            plateSlot:SetPosition(g_UXOfficial_ESPV2(0,0))
            plateSlot:SetSize(g_UXOfficial_ESPV2(180,28))
            plateSlot:SetZOrder(0)
        end
        if badgeSlot then
            badgeSlot:SetAutoSize(false)
            badgeSlot:SetPosition(g_UXOfficial_ESPV2(8,0))
            badgeSlot:SetSize(g_UXOfficial_ESPV2(22,28))
            badgeSlot:SetZOrder(2)
        end
        nameSlot:SetAutoSize(true)
        nameSlot:SetAlignment(g_UXOfficial_ESPV2(0.5, 0.5))
        nameSlot:SetZOrder(1)
        distanceSlot:SetAutoSize(true)
        distanceSlot:SetAlignment(g_UXOfficial_ESPV2(0.5, 0.5))
        distanceSlot:SetZOrder(1)
    end)

    local data={
        Widget = container,
        Text = nameText,
        DistanceText = distanceText,
        Plate = namePlate,
        PlateSlot = plateSlot,
        BadgeText = badgeText,
        BadgeSlot = badgeSlot,
        TextSlot = nameSlot,
        DistanceSlot = distanceSlot,
        Slot = mainSlot,
        IsBot = isBot
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,"NameV2",canvas,data)
end

-- ESP enemy name and distance made by @UXOfficial
local function g_UXOfficial_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, forceName, forceDistance, distanceColor, distanceColorKey)
    local showName = _G.g_UXOfficial_ESPOptions.Name == true
    local showDistance = _G.g_UXOfficial_ESPOptions.Distance == true
    if forceName~=nil then showName=forceName==true end
    if forceDistance~=nil then showDistance=forceDistance==true end
    local data = g_UXOfficial_ShotESP.Names[key]
    if not showName and not showDistance then
        if data and data.ContainerVisible~=false and g_UXOfficial_ESPValid(data.Widget) then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.ContainerVisible=false end
        return
    end
    -- Fix: only cache non-empty resolved names; "" is truthy in Lua so never cache it
    local name = nil
    if showName then
        local cached = data and data.CachedName
        if type(cached) == "string" and #cached > 0 then
            name = cached
        else
            name = g_UXOfficial_ESPResolvePlayerName(character)
            if data and type(name) == "string" and #name > 0 then
                data.CachedName = name
            end
        end
        -- Fallback label for display only (not cached, so future frames retry)
        if not (type(name) == "string" and #name > 0) then
            name = isBot and "BOT PLAYER" or "PLAYER"
        end
    else
        name = ""
    end
    if not headScreen then
        if data and g_UXOfficial_ESPValid(data.Widget) then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.ContainerVisible=false
        end
        return
    end

    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        g_UXOfficial_ESPDestroyWidgetData(data)
        data = g_UXOfficial_ESPCreateNameTag(isBot)
        g_UXOfficial_ShotESP.Names[key] = data
        -- Only cache real resolved names on creation, not fallback labels
        if data and type(name)=="string" and #name>0 and name~="BOT" and name~="BOT PLAYER" and name~="PLAYER" then
            data.CachedName = name
        end
    end
    if not data then return end
    if data.IsBot~=isBot then
        local theme=g_UXOfficial_ESPTheme(isBot)
        g_UXOfficial_ESPSetTextColor(data.Text,theme.Text)
        data.IsBot=isBot
    end
    -- Distance label always uses the exact same live color as the skeleton
    -- and snap line: cover = black; otherwise health = red/yellow/green.
    if distanceColor then
        g_UXOfficial_ESPSetTextColor(data.DistanceText,distanceColor)
        data.DistanceColorKey=distanceColorKey
    end

    local dist = math.max(0, math.floor((tonumber(distance) or 0) + 0.5))
    local distanceLabel = string.format("%dm", dist)

    local bodyH=(footScreen and math.abs(footScreen.Y-headScreen.Y)) or 120.0
    local charCount=#name
    pcall(function() if utf8 and utf8.len then charCount=utf8.len(name) or charCount end end)
    -- Same compact, bottom-anchored geometry as ESPUpdateHeaderFrame.
    local w=math.max(68.0,math.min(232.0,bodyH*0.315))
    w=math.max(w,math.min(220.0,24.0+charCount*5.2))
    local hh=math.max(18.0,math.min(48.0,bodyH*0.070))
    local nameScale=math.max(0.62,math.min(0.90,math.min(bodyH/390.0,(w*0.76)/math.max(1.0,charCount*7.2))))
    local distanceScale=math.max(0.52,math.min(0.92,bodyH/250.0))
    local offscreenDistance = forceDistance==true and forceName==false
    if offscreenDistance then distanceScale=math.max(distanceScale,0.78) end

    -- Anchor the lower edge above the head; only the upper edge expands with scale.
    local cx = headScreen.X
    local headGap=math.max(4.0,math.min(10.0,bodyH*0.025))
    local bottomY=headScreen.Y-headGap
    local x = cx - w*0.5
    local y = bottomY-hh

    -- Distance text: at FEET position (CanvasPanel doesn't clip children outside bounds)
    local footY = footScreen and footScreen.Y or (headScreen.Y + bodyH)
    local distY = (footY - y) + bodyH*0.020   -- relative to container top-left, at feet level
    local distX = footScreen and (footScreen.X - x) or (w*0.5)

    local nameVisibilityChanged=data.ShowName~=showName
    local distanceVisibilityChanged=data.ShowDistance~=showDistance
    local layoutChanged=not data.LayoutX or math.abs(data.LayoutX-x)>=0.25 or math.abs(data.LayoutY-y)>=0.25 or
        math.abs((data.LayoutW or 0)-w)>=0.25 or math.abs((data.LayoutH or 0)-hh)>=0.25

    local applied = pcall(function()
        local targetPrefix = isBot and "BOT  /  " or "TARGET  /  "
        local shownName = showName and (targetPrefix .. name) or ""
        local shownDistance = showDistance and distanceLabel or ""
        if data.PlateSlot then
            data.PlateSlot:SetSize(g_UXOfficial_ESPV2(math.max(112.0,math.min(250.0,w+22.0)),hh))
        end
        if data.BadgeText and data.LastBadgeType ~= isBot then
            data.BadgeText:SetText(isBot and "B" or "D")
            data.LastBadgeType = isBot
        end
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.NameScale~=nameScale then data.Text:SetRenderScale(g_UXOfficial_ESPV2(nameScale,nameScale)) end
        if data.DistanceScale~=distanceScale then data.DistanceText:SetRenderScale(g_UXOfficial_ESPV2(distanceScale,distanceScale)) end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
        if nameVisibilityChanged then
            data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end
        if distanceVisibilityChanged then
            data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end

        -- Move the container to match the header octagon exactly
        if layoutChanged then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x, y))
            data.Slot:SetSize(g_UXOfficial_ESPV2(w, hh))
        end

        -- Name text centered inside container (matches header box center)
        if data.LayoutW~=w or data.LayoutH~=hh then
            data.TextSlot:SetPosition(g_UXOfficial_ESPV2(w*0.5, hh*0.5))
        end

        -- Distance text below the header box
        local distChanged = not data.DistX or math.abs(data.DistX-distX)>=0.25 or math.abs((data.DistY or 0)-distY)>=0.25
        if distChanged then
            data.DistanceSlot:SetPosition(g_UXOfficial_ESPV2(distX, distY))
        end

        if data.ContainerVisible~=true then
            data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
    end)
    if not applied then return end
    data.ShowName,data.ShowDistance=showName,showDistance
    data.NameScale=nameScale
    data.DistanceScale=distanceScale
    data.LayoutX,data.LayoutY,data.LayoutW,data.LayoutH=x,y,w,hh
    data.DistX,data.DistY=distX,distY
    data.ContainerVisible=true
end

-- Unified premium gold HUD: enemy/bot counter + model-target plates
local function g_UXOfficial_ESPCreateCounter()
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local container=nil
    pcall(function() container=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_UXOfficial_ESPValid(container) then return nil end
    -- Compact premium frame: player side uses the visibility/health palette; bot side uses teal.
    local displayW,displayH=360.0,46.0
    local fontSize,fontScale=12,0.94
    local width,height,shieldH=410.0,48.0,56.0
    local sx,sy=displayW/width,displayH/shieldH
    local strokeScale=math.min(sx,sy)
    local half=width*0.5
    local pieces={}

    local function addRect(x,y,w,h,color,z)
        local widget=nil
        pcall(function() widget=CGame:NewObjectFromPath("/Script/UMG.Border",container) end)
        if not g_UXOfficial_ESPValid(widget) then return nil end
        local slot=nil
        pcall(function()
            widget:SetBrushColor(color)
            widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slot=container:AddChildToCanvas(widget)
            slot:SetAutoSize(false)
            slot:SetPosition(g_UXOfficial_ESPV2(x*sx,y*sy))
            slot:SetSize(g_UXOfficial_ESPV2(math.max(1.0,w*sx),math.max(1.0,h*sy)))
            slot:SetZOrder(z or 1)
        end)
        if not slot then return nil end
        pieces[#pieces+1]={Widget=widget,Slot=slot}
        return pieces[#pieces]
    end

    local function addLine(x1,y1,x2,y2,thickness,color,z)
        local line=g_UXOfficial_ESPCreateLine(color,container)
        if not line then return nil end
        pcall(function() line.Slot:SetZOrder(z or 8) end)
        g_UXOfficial_ESPDrawLine(line,x1*sx,y1*sy,x2*sx,y2*sy,thickness*strokeScale)
        pieces[#pieces+1]=line
        return line
    end

    -- VIPGROUP  counter face: layered armored plates with a clear center divider.
    -- The live counts, visibility toggles, and update cadence remain unchanged.
    local panelSteps=18
    local bandH=height/panelSteps
    for i=1,panelSteps do
        local y=(i-1)*bandH
        local t=(i-0.5)/panelSteps
        local outerInset=4.0+t*19.0
        local innerInset=48.0-t*31.0
        local leftRight=half-innerInset
        local rightLeft=half+innerInset
        local enemyBase=g_UXOfficial_ESPColor(0.055,0.17,0.075,0.76+t*0.08)
        local botBase=g_UXOfficial_ESPColor(0.045,0.10,0.20,0.76+t*0.08)
        addRect(outerInset,y,leftRight-outerInset,bandH+0.15,enemyBase,1)
        addRect(rightLeft,y,width-outerInset-rightLeft,bandH+0.15,botBase,1)
    end

    -- Military status palette: green hostiles panel, blue bot panel, amber warning seams.
    local enemyGlow={
        g_UXOfficial_ESPColor(0.20,0.98,0.34,1.0),
        g_UXOfficial_ESPColor(0.66,0.92,0.20,1.0),
        g_UXOfficial_ESPColor(1.0,0.78,0.12,1.0),
        g_UXOfficial_ESPColor(0.22,0.72,0.30,1.0),
        g_UXOfficial_ESPColor(0.92,0.92,0.42,1.0),
        g_UXOfficial_ESPColor(0.30,0.86,0.38,1.0)
    }
    local enemyMultiColorPieces={}
    local lp={{4,3},{half-48,3},{half-26,height*0.62},{half-13,height-3},{25,height-3},{4,3}}
    local rp={{width-4,3},{half+48,3},{half+26,height*0.62},{half+13,height-3},{width-25,height-3},{width-4,3}}
    for i=1,#lp-1 do
        addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],2.0,enemyGlow[i],6)
        local glowPiece=addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],3.1,enemyGlow[i],7)
        if glowPiece and glowPiece.Widget then
            pcall(function() glowPiece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            enemyMultiColorPieces[#enemyMultiColorPieces+1]=glowPiece
        end
    end
    local botAccent=g_UXOfficial_ESPColor(0.20,0.62,1.0,1.0)
    for i=1,#rp-1 do addLine(rp[i][1],rp[i][2],rp[i+1][1],rp[i+1][2],2.8,botAccent,7) end

    -- Central armored spine with stepped warning bars and a downward shield tip.
    local shieldSteps=24
    local shieldBand=shieldH/shieldSteps
    for i=1,shieldSteps do
        local y=(i-1)*shieldBand
        local t=(i-0.5)/shieldSteps
        local hw
        if t<0.58 then hw=39.0-t*17.0 else hw=29.0-(t-0.58)*46.0 end
        hw=math.max(10.0,hw)
        local centerColor=(i%4==0) and g_UXOfficial_ESPColor(0.28,0.34,0.12,0.98) or ESP_COUNTER_CENTER
        addRect(half-hw,y,hw*2.0,shieldBand+0.15,centerColor,5)
    end
    addLine(half-7,4,half-7,height*0.64,1.2,g_UXOfficial_ESPColor(0.92,0.72,0.16,0.96),8)
    addLine(half+7,4,half+7,height*0.64,1.2,g_UXOfficial_ESPColor(0.92,0.72,0.16,0.96),8)

    -- Heavy-duty corner claws, stepped lower rails and a bright central insignia.
    addLine(5,4,17,height-5,4.0,enemyGlow[1],9)
    addLine(14,4,26,height-5,2.0,enemyGlow[3],9)
    addLine(width-5,4,width-17,height-5,4.0,botAccent,9)
    addLine(width-14,4,width-26,height-5,2.0,botAccent,9)
    addLine(half-17,5,half-9,height*0.58,4.5,enemyGlow[2],10)
    addLine(half+17,5,half+9,height*0.58,4.5,botAccent,10)
    addLine(half-14,16,half,43,6.0,g_UXOfficial_ESPColor(0.98,0.84,0.30,1.0),11)
    addLine(half+14,16,half,43,6.0,g_UXOfficial_ESPColor(0.98,0.84,0.30,1.0),11)
    for i=0,5 do
        local x=half-38+i*15
        addRect(x,3,8,2.0,(i%2==0) and enemyGlow[3] or botAccent,8)
    end

    local function addText(initial,x,color)
        local text=nil
        pcall(function() text=CGame:NewObjectFromPath("/Script/UMG.TextBlock",container) end)
        if not g_UXOfficial_ESPValid(text) then return nil,nil end
        local slot=nil
        pcall(function()
            text:SetText(initial)
            text:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if text.SetJustification then text:SetJustification(1) end
            slot=container:AddChildToCanvas(text)
            slot:SetAutoSize(true)
            slot:SetAlignment(g_UXOfficial_ESPV2(0.5,0.5))
            slot:SetPosition(g_UXOfficial_ESPV2(x*sx,displayH*0.5))
            slot:SetZOrder(12)
        end)
        g_UXOfficial_ESPSetTextColor(text,color)
        g_UXOfficial_ESPSetFont(text,fontSize,0)
        pcall(function()
            text:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.5,0.5))
            text:SetRenderScale(g_UXOfficial_ESPV2(fontScale,fontScale))
        end)
        return text,slot
    end

    -- Refined dragon-inspired wing blades: abstract, sharp and non-cartoon.
    -- Left wing/head silhouette.
    addLine(12,29,27,12,2.2,enemyGlow[1],10)
    addLine(27,12,25,25,1.8,enemyGlow[2],10)
    addLine(25,25,43,18,1.8,enemyGlow[3],10)
    addLine(12,29,31,29,1.5,enemyGlow[4],10)
    addLine(31,29,44,40,1.8,enemyGlow[2],10)
    addLine(44,40,27,36,1.5,enemyGlow[3],10)
    addLine(27,36,12,29,1.5,enemyGlow[1],10)
    -- Right wing/tail silhouette, mirrored with a tapered tail finish.
    addLine(width-12,29,width-27,12,2.2,botAccent,10)
    addLine(width-27,12,width-25,25,1.8,botAccent,10)
    addLine(width-25,25,width-43,18,1.8,botAccent,10)
    addLine(width-12,29,width-31,29,1.5,botAccent,10)
    addLine(width-31,29,width-44,40,1.8,botAccent,10)
    addLine(width-44,40,width-27,36,1.5,botAccent,10)
    addLine(width-27,36,width-12,29,1.5,botAccent,10)

    local realText=addText("ENEMIES: 0",half*0.5+16,enemyGlow[3])
    local botText=addText("BOTS: 0",half+half*0.5-16,botAccent)
    if not realText or not botText then
        g_UXOfficial_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainSlot=nil
    pcall(function() mainSlot=canvas:AddChildToCanvas(container) end)
    if not mainSlot then g_UXOfficial_ESPDestroyWidgetData({Widget=container}) return nil end

    local anchored=false
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_UXOfficial_ESPV2(displayW,displayH))
        mainSlot:SetZOrder(60)
        -- Viewport-independent top-center anchor: survives aspect ratio, DPI,
        -- notch and safe-zone variations without drifting toward a corner.
        if mainSlot.SetAnchors and Anchors then
            local anchors=nil
            pcall(function()
                anchors=Anchors(
                    g_UXOfficial_ESPV2(0.5,0.0),
                    g_UXOfficial_ESPV2(0.5,0.0)
                )
            end)
            if not anchors then pcall(function() anchors=Anchors() end) end
            if anchors then
                pcall(function() anchors.Minimum=g_UXOfficial_ESPV2(0.5,0.0) end)
                pcall(function() anchors.Maximum=g_UXOfficial_ESPV2(0.5,0.0) end)
                mainSlot:SetAnchors(anchors)
                mainSlot:SetAlignment(g_UXOfficial_ESPV2(0.5,0.0))
                anchored=true
            end
        end
    end)

    return {Widget=container,Slot=mainSlot,RealText=realText,BotText=botText,
        EnemyMultiColorPieces=enemyMultiColorPieces,
        Width=displayW,Height=displayH,FontSize=fontSize,FontScale=fontScale,DiamondSize=0,Pieces=pieces,ViewportAnchored=anchored}
end

-- ESP counter position and tracer origin made by @UXOfficial
local function g_UXOfficial_ESPUpdateCounter(realCount, botCount, pc)

    local data = g_UXOfficial_ShotESP.Counter
    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        -- The static counter is built atomically; the budget applies to enemy
        -- line groups that would otherwise all spawn together.
        local budget = g_UXOfficial_ShotESP.BuildRemaining
        g_UXOfficial_ShotESP.BuildRemaining = nil
        data = g_UXOfficial_ESPCreateCounter()
        g_UXOfficial_ShotESP.BuildRemaining = budget
        g_UXOfficial_ShotESP.Counter = data
    end
    if not data then return nil end

    -- Activate the enemy-side multicolor treatment only while real enemies are present.
    local showEnemyMultiColor=(tonumber(realCount) or 0)>0
    if data.EnemyMultiColorPieces and data.EnemyMultiColorVisible~=showEnemyMultiColor then
        for _,piece in ipairs(data.EnemyMultiColorPieces) do
            if piece and piece.Widget and g_UXOfficial_ESPValid(piece.Widget) then
                pcall(function()
                    piece.Widget:SetWidgetVisibility(showEnemyMultiColor and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
                end)
            end
        end
        data.EnemyMultiColorVisible=showEnemyMultiColor
    end

    local cw = g_UXOfficial_ShotESP.ViewportW
    local centerX = nil

    if tonumber(cw) and cw > 1 then
        centerX = cw * 0.5
    else

        local vw = g_UXOfficial_ESPViewport(pc)
        centerX =
            (vw * 0.5) * (g_UXOfficial_ShotESP.CanvasScaleX or 1.0)
            + (g_UXOfficial_ShotESP.CanvasOffsetX or 0.0)
    end

    if not centerX then return nil end

    local counterY = tonumber(_G.g_UXOfficial_UXOfficialShotESP.CounterY) or 36.0

    if data.LastReal ~= realCount then
        local ok=pcall(function() data.RealText:SetText(string.format("ENEMIES: %d", realCount or 0)) end)
        if ok then data.LastReal = realCount end
    end
    if data.LastBot ~= botCount then
        local ok=pcall(function() data.BotText:SetText(string.format("BOTS: %d", botCount or 0)) end)
        if ok then data.LastBot = botCount end
    end

    local positionChanged = data.CenterX ~= centerX or data.CounterY ~= counterY
    local visibleChanged = data.Visible ~= true
    local applied = pcall(function()
        if positionChanged and data.ViewportAnchored then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(0.0,counterY))
        elseif positionChanged then
            data.Slot:SetAlignment(g_UXOfficial_ESPV2(0.0,0.0))
            data.Slot:SetPosition(g_UXOfficial_ESPV2(centerX-data.Width*0.5,counterY))
        end
        if visibleChanged then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if applied then data.CenterX,data.CounterY,data.Visible = centerX,counterY,true end

    local diamondSize = tonumber(data.DiamondSize) or 20.0
    local anchorX = centerX
    local anchorY = counterY + (data.Height * 0.5) + (diamondSize / math.sqrt(2.0))

    data.AnchorX = anchorX
    data.AnchorY = anchorY

    g_UXOfficial_ShotESP.TracerOrigin = g_UXOfficial_ESPV2(anchorX, anchorY)
    return g_UXOfficial_ShotESP.TracerOrigin
end

-- ESP enemy scan made by @UXOfficial
local function g_UXOfficial_ESPScanEnemies()
    local pc = g_UXOfficial_ESPGetController()
    local me = g_UXOfficial_ESPGetLocalCharacter()
    if not pc or not me then g_UXOfficial_ShotESP.Enemies = {} return nil, 0, 0 end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then g_UXOfficial_ShotESP.Enemies = {} return pc, 0, 0 end
    local myTeam = g_UXOfficial_ESPGetTeamID(me)

    local list = {}
    local realCount, botCount = 0, 0
    local pawns=ESPShared.GetFramePawns()
    pawns = pawns or _G.g_UXOfficial_TrackedCharacters
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive then
                local team = g_UXOfficial_ESPGetTeamID(character)
                -- Fix: only skip as same-team when both IDs are non-zero and equal
                local sameTeam = false
                if myTeam ~= nil and team ~= nil then
                    local tNum, mNum = tonumber(team), tonumber(myTeam)
                    sameTeam = tNum and mNum and tNum > 0 and mNum > 0 and tNum == mNum
                end
                if not sameTeam then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters) or 400.0) then
                        local key = g_UXOfficial_ESPGetPlayerKey(character)
                        local isBot = g_UXOfficial_ESPIsBot(character,key)
                        if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        list[#list+1] = {Character=character, Key=key, IsBot=isBot, Distance=dist}
                    end
                end
            end
        end
    end
    table.sort(list, function(a,b)
        if a.Distance == b.Distance then return a.Key < b.Key end
        return (a.Distance or 99999) < (b.Distance or 99999)
    end)
    g_UXOfficial_ShotESP.Enemies = list
    return pc, realCount, botCount
end

-- ESP stale widget cleanup made by @UXOfficial
local function g_UXOfficial_ESPPrune(active,alive)
    -- Visual caches follow the displayed set. Counting metadata follows alive.
    -- Move header children into their actor-free parent bundle before pruning
    -- either registry; no detached child can follow a different enemy.
    for key,root in pairs(g_UXOfficial_ShotESP.HeaderRoots) do
        if not active[key] and root.PoolOwner and root.Groups then
            root.Groups.__Header=g_UXOfficial_ShotESP.Headers[key]
            g_UXOfficial_ShotESP.Headers[key]=nil
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.Lines,g_UXOfficial_ShotESP.Names,
        g_UXOfficial_ShotESP.Decorations,g_UXOfficial_ShotESP.HeaderRoots}) do
        for key,data in pairs(registry) do
            if not active[key] then g_UXOfficial_ESPDestroyWidgetData(data);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.Boxes,g_UXOfficial_ShotESP.HealthBars,
        g_UXOfficial_ShotESP.Skeletons,g_UXOfficial_ShotESP.Headers,g_UXOfficial_ShotESP.Footers}) do
        for key,group in pairs(registry) do
            if not active[key] then g_UXOfficial_ESPDestroyGroup(group);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.BuildStage,g_UXOfficial_ShotESP.BoneNameCache,
        g_UXOfficial_ShotESP.BoneMeshes,g_UXOfficial_ShotESP.BonePoints}) do
        for key in pairs(registry) do if not active[key] then registry[key]=nil end end
    end
    for key in pairs(g_UXOfficial_ShotESP._BotCache) do if not alive[key] then g_UXOfficial_ShotESP._BotCache[key]=nil end end
end

-- Vehicle tracking bridge: the host/game-specific vehicle scanner can register actor references here.
-- Example: g_UXOfficial_TrackRadarVehicle(vehicleActor). The radar validates actors before drawing.
_G.g_UXOfficial_TrackedVehicles = _G.g_UXOfficial_TrackedVehicles or {}
function _G.g_UXOfficial_TrackRadarVehicle(vehicleActor)
    if not vehicleActor then return false end
    local valid=false
    pcall(function() valid=vehicleActor.K2_GetActorLocation~=nil end)
    if not valid then return false end
    local list=_G.g_UXOfficial_TrackedVehicles
    for _,entry in pairs(list) do
        local actor=type(entry)=="table" and (entry.Vehicle or entry.Actor or entry[1]) or entry
        if actor==vehicleActor then return true end
    end
    list[#list+1]=vehicleActor
    return true
end
function _G.g_UXOfficial_ClearRadarVehicles()
    _G.g_UXOfficial_TrackedVehicles = {}
end

-- Compact side radar (green player arrow, red real enemies, yellow bots, pink tracked vehicles).
-- Uses the already-collected target list; optional vehicles can be supplied through
-- _G.g_UXOfficial_TrackedVehicles as an array of actor references or {Vehicle=actor} records.
local function g_UXOfficial_ESPRadarLine(index, color)
    local state=g_UXOfficial_ShotESP
    local line=state.RadarLines[index]
    if line and (line.Broken or not g_UXOfficial_ESPValid(line.Widget)) then
        g_UXOfficial_ESPDestroyWidgetData(line); state.RadarLines[index]=nil; line=nil
    end
    if not line then
        line=g_UXOfficial_ESPCreateLine(color)
        if line then state.RadarLines[index]=line end
    else
        if line.RadarColor~=color then pcall(function() line.Widget:SetBrushColor(color) end); line.RadarColor=color end
    end
    return line
end

-- Track lines drawn in the current frame so stale radar markers are hidden safely.
local g_UXOfficial_RadarActiveLines = {}

local function g_UXOfficial_ESPRadarDraw(index, x1,y1,x2,y2,thick,color)
    local line=g_UXOfficial_ESPRadarLine(index,color)
    if line then
        g_UXOfficial_ESPDrawLine(line,x1,y1,x2,y2,thick)
        g_UXOfficial_RadarActiveLines[index] = true
    end
end

local function g_UXOfficial_ESPRadarHideInactive()
    local state=g_UXOfficial_ShotESP
    if not state or type(state.RadarLines)~="table" then return end
    for i,line in pairs(state.RadarLines) do
        if line and not g_UXOfficial_RadarActiveLines[i] then
            g_UXOfficial_ESPHide(line)
        end
    end
end

local function g_UXOfficial_ESPRadarHideFrom(index)
    local state=g_UXOfficial_ShotESP
    if not state or type(state.RadarLines)~="table" then return end
    for i,line in pairs(state.RadarLines) do
        if i>=index and line then g_UXOfficial_ESPHide(line) end
    end
end

local function g_UXOfficial_ESPRadarEnsureControls(canvas,canvasW,canvasH)
    -- Side radar is automatic: remove the old floating RADAR / close controls.
    -- The existing ESP menu option named RADAR MAP remains the master on/off switch.
    local state=g_UXOfficial_ShotESP
    local ui=state.RadarUI
    if ui then
        for _,name in ipairs({"ToggleEvent","CloseEvent"}) do
            local ev,handle=ui[name],ui[name.."Handle"]
            if ev and handle~=nil then pcall(function() ev:Remove(handle) end) end
        end
        for _,name in ipairs({"ToggleLabel","ToggleButton","CloseLabel","CloseButton"}) do
            if g_UXOfficial_ESPValid(ui[name]) then pcall(function() ui[name]:RemoveFromParent() end) end
        end
        state.RadarUI=nil
        state.RadarCanvas=nil
    end
    state.RadarOpen=true
end

local function g_UXOfficial_ESPUpdateRadar(canvasW,canvasH,me,myLoc,items)
    if not canvasW or not canvasH or not me or not myLoc then return end
    local state=g_UXOfficial_ShotESP
    g_UXOfficial_RadarActiveLines = {}
    local canvas=g_UXOfficial_ESPGetCanvas()
    g_UXOfficial_ESPRadarEnsureControls(canvas,canvasW,canvasH)
    if _G.g_UXOfficial_ESPOptions.Radar~=true then
        g_UXOfficial_ESPRadarHideFrom(1)
        return
    end
    -- Compact always-visible side radar; no floating toggle and no expanded-map mode.
    local radius=math.max(52.0,math.min(88.0,canvasW*0.075,canvasH*0.14))
    local cx=canvasW-radius-34.0
    local cy=canvasH*0.62
    local rangeMeters=200.0
    local yaw=0.0
    pcall(function()
        local rot=me:K2_GetActorRotation()
        yaw=math.rad(tonumber(rot.Yaw) or 0.0)
    end)
    local idx=1
    -- VIPGROUP  tactical radar UI: faceted octagonal instrument frame.
    -- Static frame colors are graphite/olive; target signal colors are defined
    -- separately below and remain fixed (green/yellow/red/blue + vehicle violet).
    local radarFrame=g_UXOfficial_ESPColor(0.52,0.68,0.28,0.98)
    local radarGrid=g_UXOfficial_ESPColor(0.22,0.30,0.18,0.86)
    local radarRingOuter=g_UXOfficial_ESPColor(0.48,0.60,0.30,0.92)
    local radarRingInner=g_UXOfficial_ESPColor(0.26,0.38,0.22,0.88)
    local radarGreen=g_UXOfficial_ESPColor(0.18,0.92,0.32,1.0) -- ownship / healthy signal
    local radarFillLine=g_UXOfficial_ESPColor(0.012,0.020,0.014,0.98)
    local box=radius+12.0
    local outerRadius=radius+7.0
    local innerRadius=radius+1.0

    -- Eight hard-edged armor facets instead of the old circular/gold surround.
    local function radarPoint(r,side)
        local a=-math.pi*0.5+(side/8.0)*math.pi*2.0
        return cx+math.cos(a)*r,cy+math.sin(a)*r
    end
    for side=0,7 do
        local x1,y1=radarPoint(outerRadius,side)
        local x2,y2=radarPoint(outerRadius,side+1)
        g_UXOfficial_ESPRadarDraw(idx,x1,y1,x2,y2,2.7,radarFrame); idx=idx+1
        local ix1,iy1=radarPoint(innerRadius,side)
        local ix2,iy2=radarPoint(innerRadius,side+1)
        g_UXOfficial_ESPRadarDraw(idx,ix1,iy1,ix2,iy2,1.0,radarGrid); idx=idx+1
    end

    -- Short segmented corner armor and cardinal/diagonal instrument ticks.
    for side=0,7 do
        local x1,y1=radarPoint(box,side)
        local x2,y2=radarPoint(box-8.0,side)
        g_UXOfficial_ESPRadarDraw(idx,x1,y1,x2,y2,2.2,radarFrame); idx=idx+1
        local a=-math.pi*0.5+(side/8.0)*math.pi*2.0
        local r1=radius+4.0
        local r2=radius+10.0
        g_UXOfficial_ESPRadarDraw(idx,cx+math.cos(a)*r1,cy+math.sin(a)*r1,
            cx+math.cos(a)*r2,cy+math.sin(a)*r2,1.5,radarRingOuter); idx=idx+1
    end

    -- Faceted range rings retain the exact same 200 m scale and actor projection.
    for _,rf in ipairs({1.0,0.75,0.50,0.25}) do
        local ringColor=(rf==1.0 and radarRingOuter) or radarRingInner
        local stepsPerSide=6
        for side=0,7 do
            for step=0,stepsPerSide-1 do
                local t1=(side+step/stepsPerSide)/8.0
                local t2=(side+(step+1)/stepsPerSide)/8.0
                local a1=-math.pi*0.5+t1*math.pi*2.0
                local a2=-math.pi*0.5+t2*math.pi*2.0
                local x1,y1=cx+math.cos(a1)*radius*rf,cy+math.sin(a1)*radius*rf
                local x2,y2=cx+math.cos(a2)*radius*rf,cy+math.sin(a2)*radius*rf
                g_UXOfficial_ESPRadarDraw(idx,x1,y1,x2,y2,rf==1.0 and 1.8 or 1.15,ringColor); idx=idx+1
            end
        end
    end

    -- Restrained crosshair and four short range-axis marks.
    g_UXOfficial_ESPRadarDraw(idx,cx-radius*0.72,cy,cx+radius*0.72,cy,1.0,radarGrid); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-radius*0.72,cx,cy+radius*0.72,1.0,radarGrid); idx=idx+1
    for _,a in ipairs({0,math.pi*0.5,math.pi,math.pi*1.5}) do
        local r1=radius*0.78
        local r2=radius*0.90
        g_UXOfficial_ESPRadarDraw(idx,cx+math.cos(a)*r1,cy+math.sin(a)*r1,
            cx+math.cos(a)*r2,cy+math.sin(a)*r2,1.6,radarRingOuter); idx=idx+1
    end

    -- Ownship chevron remains green; target dots below use the fixed military palette.
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-9,cx-7,cy+7,3.0,radarGreen); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-9,cx+7,cy+7,3.0,radarGreen); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-7,cy+7,cx+7,cy+7,3.0,radarGreen); idx=idx+1

    local function drawDot(actor,color,offset)
        local loc=nil
        pcall(function()
            if actor and actor.K2_GetActorLocation then loc=actor:K2_GetActorLocation() end
        end)
        if not loc then
            local rec=nil; pcall(function() rec=ESPShared.GetFrameRecord(actor) end)
            loc=rec and rec.Location or nil
        end
        if not loc then return end
        local dx=(tonumber(loc.X) or 0)-(tonumber(myLoc.X) or 0)
        local dy=(tonumber(loc.Y) or 0)-(tonumber(myLoc.Y) or 0)
        local forward=dx*math.cos(yaw)+dy*math.sin(yaw)
        local right=-dx*math.sin(yaw)+dy*math.cos(yaw)
        local mx,my=right/100.0,forward/100.0
        local dist=math.sqrt(mx*mx+my*my)
        if dist>rangeMeters then return end
        local scale=math.min(1.0,dist/rangeMeters)
        local px=cx+(mx/rangeMeters)*radius
        local py=cy-(my/rangeMeters)*radius
        local sz=dist<25 and 3.4 or 2.5
        g_UXOfficial_ESPRadarDraw(offset,px-sz,py,px+sz,py,2.8,color)
        g_UXOfficial_ESPRadarDraw(offset+1,px,py-sz,px,py+sz,2.8,color)
    end
    -- Keep actor tracking and positions unchanged; distinguish bots from real enemies by color.
    local dotIndex=idx
    local drawn=0
    local radarGreen=g_UXOfficial_ESPColor(0.18,0.92,0.32,1.0) -- healthy real target
    local radarYellow=g_UXOfficial_ESPColor(1.0,0.82,0.12,1.0) -- damaged real target
    local radarRed=g_UXOfficial_ESPColor(1.0,0.16,0.12,1.0) -- critical real target
    local botYellow=g_UXOfficial_ESPColor(0.18,0.58,1.0,1.0) -- bot / blue signal
    for _,item in ipairs(items or {}) do
        if drawn>=12 then break end
        local color=botYellow
        if not (item and item.IsBot) then
            local hpRatio=g_UXOfficial_ESPHealthRatio(item.Character)
            if hpRatio<=0.30 then
                color=radarRed
            elseif hpRatio<0.999 then
                color=radarYellow
            else
                color=radarGreen
            end
        end
        drawDot(item.Character,color,dotIndex)
        dotIndex=dotIndex+2; drawn=drawn+1
    end
    -- Tracked vehicles use a distinct violet signal, separate from player and bot tones.
    local vehicles=_G.g_UXOfficial_TrackedVehicles
    local pink=g_UXOfficial_ESPColor(0.78,0.42,1.0,1.0)
    if type(vehicles)=="table" then
        local vdrawn=0
        for _,entry in pairs(vehicles) do
            if vdrawn>=12 then break end
            local vehicle=entry
            if type(entry)=="table" then vehicle=entry.Vehicle or entry.Actor or entry.Character or entry.Pawn or entry[1] end
            if vehicle then
                local valid=false
                pcall(function() valid=vehicle.K2_GetActorLocation~=nil end)
                if valid then drawDot(vehicle,pink,dotIndex); dotIndex=dotIndex+2; vdrawn=vdrawn+1 end
            end
        end
    end
    g_UXOfficial_ESPRadarHideInactive()
end

-- ESP main HUD update made by @UXOfficial
local function g_UXOfficial_ESPUpdate()
    if _G.AHMADAuthActive and not _G.AHMADAuthActive() then return end
    local opt = _G.g_UXOfficial_ESPOptions
    local anyEnabled = opt and (opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton or opt.Counter or opt.Radar)
    if not _G.g_UXOfficial_UXOfficialShotESP.Enabled or not anyEnabled then
        if not g_UXOfficial_ShotESP.Disabled then g_UXOfficial_ESPResetWidgets() end
        g_UXOfficial_ShotESP.Disabled = true
        return
    end
    g_UXOfficial_ShotESP.Disabled = false
    local buildBudget = tonumber(_G.g_UXOfficial_UXOfficialShotESP.WidgetBuildBudget) or 96
    if buildBudget ~= buildBudget or buildBudget == math.huge then buildBudget = 96 end
    g_UXOfficial_ShotESP.BuildRemaining = math.max(1, math.floor(buildBudget))

    local world = g_UXOfficial_ESPWorld()
    if world ~= g_UXOfficial_ShotESP.LastWorld then
        g_UXOfficial_ESPResetWidgets()
        g_UXOfficial_ShotESP.LastWorld = world
        g_UXOfficial_ShotESP.LastScanClock = -999.0
        g_UXOfficial_ShotESP.LastTransformClock = -999.0
        g_UXOfficial_ShotESP.TracerOrigin = nil
    end

    if g_UXOfficial_ShotESP.Canvas and not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.Canvas) then
        g_UXOfficial_ESPResetWidgets()
    end
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not canvas then return end
    local now = g_UXOfficial_ESPNow()
    g_UXOfficial_ShotESP.Now = now
    if now < g_UXOfficial_ShotESP.LastScanClock then
        g_UXOfficial_ShotESP.LastScanClock = -999.0
        g_UXOfficial_ShotESP.LastTransformClock = -999.0
    end
    local pc = g_UXOfficial_ESPGetController()
    local me = g_UXOfficial_ESPGetLocalCharacter()
    if pc ~= g_UXOfficial_ShotESP.LastController or me ~= g_UXOfficial_ShotESP.LastPawn then
        g_UXOfficial_ESPResetWidgets()
        g_UXOfficial_ShotESP.LastController, g_UXOfficial_ShotESP.LastPawn = pc,me
        canvas = g_UXOfficial_ESPGetCanvas()
        if not canvas then return end
    end
    if not pc or not me then return end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    local realCount, botCount = nil, nil
    if (now - g_UXOfficial_ShotESP.LastScanClock) >= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.ScanInterval) or 0.30) then
        pc, realCount, botCount = g_UXOfficial_ESPScanEnemies()
        g_UXOfficial_ShotESP.LastScanClock = now
        g_UXOfficial_ShotESP.RealCount, g_UXOfficial_ShotESP.BotCount = realCount, botCount
    end
    pc = pc or g_UXOfficial_ESPGetController()
    if not pc then return end

    if (now - (g_UXOfficial_ShotESP.LastTransformClock or -999.0))
        >= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.TransformInterval) or 0.50) then
        g_UXOfficial_ESPUpdateCanvasTransform(pc)
        local cw,ch=g_UXOfficial_ESPGetCanvasLocalSize()
        if cw and ch then g_UXOfficial_ShotESP.ViewportW,g_UXOfficial_ShotESP.ViewportH=cw,ch end
        local rw,rh=g_UXOfficial_ESPViewport(pc)
        g_UXOfficial_ShotESP.RawViewportW,g_UXOfficial_ShotESP.RawViewportH=rw,rh
        g_UXOfficial_ShotESP.LastTransformClock = now
    end

    local rawW,rawH=ESPShared.ViewSize(pc)
    -- The tracer uses the physical viewport midpoint in canvas coordinates.
    local canvasScaleX=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasScaleX,1.0,0.00001,100)
    local canvasScaleY=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasScaleY,1.0,0.00001,100)
    local canvasOffsetX=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasOffsetX,0.0,-1e7,1e7)
    local canvasOffsetY=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasOffsetY,0.0,-1e7,1e7)
    local originCenter = g_UXOfficial_ESPV2(
        (rawW*0.5)*canvasScaleX+canvasOffsetX,
        4.0*canvasScaleY+canvasOffsetY
    )
    local active,alive=g_UXOfficial_ShotESP.Active,g_UXOfficial_ShotESP.Alive
    g_UXOfficial_ShotESP.RealCount,g_UXOfficial_ShotESP.BotCount=g_UXOfficial_ESPFilterEnemies(
        g_UXOfficial_ShotESP.Enemies,myLoc,_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters,alive)
    local radarW,radarH=g_UXOfficial_ESPGetCanvasLocalSize()
    if radarW and radarH then g_UXOfficial_ESPUpdateRadar(radarW,radarH,me,myLoc,g_UXOfficial_ShotESP.Enemies) end
    if opt.Counter then
        g_UXOfficial_ESPUpdateCounter(
            g_UXOfficial_ShotESP.RealCount or 0,
            g_UXOfficial_ShotESP.BotCount or 0,
            pc
        )
    elseif g_UXOfficial_ShotESP.Counter then
        g_UXOfficial_ESPHide(g_UXOfficial_ShotESP.Counter)
    end

    -- Counter-only mode stops here after validating cached scan candidates, avoiding
    -- projection, skeleton, box and per-enemy widget work entirely.
    local detailedEnabled=opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton
    if not detailedEnabled then
        for key in pairs(active) do active[key]=nil end
        g_UXOfficial_ESPPrune(active,alive)
        return
    end

    for key in pairs(active) do active[key]=nil end
    local configuredMax=math.floor(ESPShared.SafeNumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRendered,8,1,64))
    local maxRendered = configuredMax
    local renderedCount=0
    -- Keep the nearest-candidate budget; counting still validates every actor.
    for index,item in ipairs(g_UXOfficial_ShotESP.Enemies) do
        if index>maxRendered then break end
        local c,key=item.Character,item.Key
        local headScreen,footScreen,onScreen=ESPShared.ProjectActor(pc,c,g_UXOfficial_ShotESP)
        if onScreen then
            if renderedCount<maxRendered then
                renderedCount=renderedCount+1
                active[key] = true
                local buildStage=g_UXOfficial_ShotESP.BuildStage[key] or 1
                -- Use the controller's native line-of-sight test: visible = yellow, blocked by cover = red.
                local isCovered = false
                pcall(function()
                    if pc.LineOfSightTo then isCovered = not pc:LineOfSightTo(c) end
                end)
                -- Healthy enemies use individual multicolors. Health warnings
                -- override that palette: damaged = yellow, critical = red.
                -- Skeleton, snap line and distance label share the same color.
                local skeletonVisibilityColor
                local colorKey
                if isCovered then
                    skeletonVisibilityColor = ESP_BLACK
                    colorKey = "COVER"
                else
                    local hpRatio = g_UXOfficial_ESPHealthRatio(c)
                    if hpRatio <= 0.30 then
                        skeletonVisibilityColor = g_UXOfficial_ESPColor(1.0,0.30,0.22,1.0)
                        colorKey = "HP_RED"
                    elseif hpRatio <= 0.70 then
                        skeletonVisibilityColor = g_UXOfficial_ESPColor(1.0,0.90,0.42,1.0)
                        colorKey = "HP_YELLOW"
                    else
                        local palette = {
                            {1.0,0.78,0.08,1.0,"YELLOW"},
                            {0.96,0.08,0.10,1.0,"RED"},
                            {0.10,0.78,1.0,1.0,"CYAN"},
                            {0.78,0.28,1.0,1.0,"PURPLE"},
                            {0.12,0.92,0.30,1.0,"GREEN"},
                            {1.0,0.48,0.08,1.0,"ORANGE"},
                            {1.0,0.30,0.62,1.0,"PINK"}
                        }
                        local paletteIndex = ((renderedCount - 1) % #palette) + 1
                        local selected = palette[paletteIndex]
                        skeletonVisibilityColor = g_UXOfficial_ESPColor(selected[1],selected[2],selected[3],selected[4])
                        colorKey = "ENEMY_" .. selected[5]
                    end
                end
                local color = skeletonVisibilityColor
                local line = g_UXOfficial_ShotESP.Lines[key]
                if opt.Line and (not line or not g_UXOfficial_ESPValid(line.Widget)) then
                    g_UXOfficial_ESPDestroyWidgetData(line)
                    line = g_UXOfficial_ESPCreateLine(color)
                    if line then line.ColorKey = colorKey end
                    g_UXOfficial_ShotESP.Lines[key] = line
                elseif opt.Line and line and line.ColorKey ~= colorKey then
                    pcall(function() line.Widget:SetBrushColor(color) end)
                    line.ColorKey = colorKey
                end

                if opt.Line and line then
                    local tracerTarget = headScreen or footScreen
                    if tracerTarget then
                        g_UXOfficial_ESPDrawLine(
                            line,
                            originCenter.X, originCenter.Y,
                            tracerTarget.X, tracerTarget.Y,
                            tonumber(_G.g_UXOfficial_UXOfficialShotESP.TracerThickness) or 1.80
                        )
                    end
                elseif line then g_UXOfficial_ESPHide(line) end

                g_UXOfficial_ESPUpdateDecoration(key,c,headScreen,footScreen,opt,buildStage,item.IsBot)
                g_UXOfficial_ESPUpdateNameTag(key,c,headScreen,footScreen,item.IsBot,item.Distance,nil,nil,skeletonVisibilityColor,colorKey)
                -- Header frame: dynamic per-frame update (fills, corner fills, scale with name)
                g_UXOfficial_ESPUpdateHeaderFrame(key,headScreen,footScreen,opt.Name==true,item.IsBot)

                -- Skeleton and snap line now share the exact same color state.
                -- All visible skeletons refresh with the current camera; no round-robin delay.
                g_UXOfficial_ESPUpdateSkeleton(key, c, pc, opt.Skeleton == true, item.IsBot,
                    skeletonVisibilityColor)
                g_UXOfficial_ShotESP.BuildStage[key]=math.min(5,buildStage+1)

            end
        end
    end
    g_UXOfficial_ESPPrune(active,alive)
end

-- One pending render chain. Menu refreshes invalidate/wake it rather than
-- drawing synchronously multiple times in the same frame.
local g_UXOfficial_ESPRunnerToken={}
if type(_G.__UXOfficialShotESPCleanup) == "function" then pcall(_G.__UXOfficialShotESPCleanup) end
_G.__UXOfficialShotESPRunner=g_UXOfficial_ESPRunnerToken
_G.__UXOfficialShotESPCleanup=g_UXOfficial_ESPResetWidgets
local g_UXOfficial_ESPDiagnostics={Updates=0,Errors=0,LastError=nil}
_G.g_UXOfficial_ESPDiagnostics=g_UXOfficial_ESPDiagnostics
local g_UXOfficial_ESPTicker=nil
pcall(function() g_UXOfficial_ESPTicker=require("common.time_ticker") end)
local g_UXOfficial_ESPTick
local function g_UXOfficial_ESPSchedule(delay)
    delay=ESPShared.SafeNumber(delay,0.50,0.001,0.50)
    if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken then return end
    if not g_UXOfficial_ESPTicker or not g_UXOfficial_ESPTicker.AddTimerOnce then
        g_UXOfficial_ESPDiagnostics.LastError="common.time_ticker.AddTimerOnce unavailable"
        return
    end
    local serial=(g_UXOfficial_ESPRunnerToken.Serial or 0)+1
    g_UXOfficial_ESPRunnerToken.Serial=serial
    g_UXOfficial_ESPRunnerToken.Due=g_UXOfficial_ESPNow()+delay
    local ok, err=pcall(g_UXOfficial_ESPTicker.AddTimerOnce,delay,function()
        if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken
            or g_UXOfficial_ESPRunnerToken.Serial~=serial then return end
        g_UXOfficial_ESPRunnerToken.Due=nil
        g_UXOfficial_ShotESP.TimerClock=g_UXOfficial_ShotESP.TimerClock+delay
        g_UXOfficial_ESPTick()
    end)
    if not ok or err==false then
        g_UXOfficial_ESPRunnerToken.Due=nil
        g_UXOfficial_ESPDiagnostics.Errors=g_UXOfficial_ESPDiagnostics.Errors+1
        g_UXOfficial_ESPDiagnostics.LastError=tostring(err)
    end
end
g_UXOfficial_ESPTick=function()
    local token=g_UXOfficial_ESPRunnerToken
    if _G.__UXOfficialShotESPRunner~=token then return end
    local now=g_UXOfficial_ESPNow()
    local profiling=_G.g_UXOfficial_UXOfficialShotESP.Profile and os and type(os.clock)=="function"
    local callbackStarted=profiling and os.clock() or nil
    ESPShared.Frame.Begin(now)
    local F=_G.LunarFeatures
    if F then F.TimerClock=g_UXOfficial_ShotESP.TimerClock end
    if not token.RenderDue or now>=token.RenderDue-0.000001 or (token.LastRenderClock and now<token.LastRenderClock) then
        local previous=g_UXOfficial_ESPDiagnostics.LastTickSeconds
        if previous and now>previous then g_UXOfficial_ESPDiagnostics.UpdateHz=1/(now-previous) end
        g_UXOfficial_ESPDiagnostics.LastTickSeconds=now
        local started=profiling and os.clock() or nil
        local ok,err=pcall(g_UXOfficial_ESPUpdate)
        g_UXOfficial_ESPDiagnostics.LastUpdateOK=ok
        g_UXOfficial_ESPDiagnostics.Updates=g_UXOfficial_ESPDiagnostics.Updates+1
        if not ok then
            g_UXOfficial_ESPDiagnostics.Errors=g_UXOfficial_ESPDiagnostics.Errors+1
            g_UXOfficial_ESPDiagnostics.LastError=tostring(err)
        end
        if started then
            local elapsed=os.clock()-started
            g_UXOfficial_ESPDiagnostics.LastUpdateCPUSeconds=elapsed
            g_UXOfficial_ESPDiagnostics.MaxUpdateCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxUpdateCPUSeconds or 0)
        end
        local o=_G.g_UXOfficial_ESPOptions or {}
        local enabled=_G.g_UXOfficial_UXOfficialShotESP.Enabled
        local detailed=enabled and (o.Name or o.Line or o.Box or o.Health or o.Distance or o.Skeleton)
        local interval=tonumber(_G.g_UXOfficial_UXOfficialShotESP.UpdateInterval) or 1/60
        if not detailed then interval=enabled and o.Counter and math.max(0.05,tonumber(_G.g_UXOfficial_UXOfficialShotESP.ScanInterval) or 0.35) or 0.50 end
        if interval~=interval or math.abs(interval)==math.huge or interval<=0 then interval=1/60 end
        token.LastRenderClock=now
        token.RenderDue=now+math.max(0.001,interval)
    end
    if profiling then g_UXOfficial_ESPDiagnostics.LastPumpCPUSeconds=0 end
    if F and F.Pump and not F.Token.Stopped then
        local pumpStarted=profiling and os.clock() or nil
        local ok,err=pcall(F.Pump,now)
        if not ok then F.Error("Scheduler",err) end
        if pumpStarted then
            local elapsed=os.clock()-pumpStarted
            g_UXOfficial_ESPDiagnostics.LastPumpCPUSeconds=elapsed
            g_UXOfficial_ESPDiagnostics.MaxPumpCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxPumpCPUSeconds or 0)
        end
    end
    ESPShared.Frame.Finish()
    local after=g_UXOfficial_ESPNow()
    local interval=math.max(0.001,token.RenderDue-after)
    if F and F.NextInterval and not F.Token.Stopped then interval=math.min(interval,F.NextInterval(after)) end
    g_UXOfficial_ESPSchedule(interval)
    if callbackStarted then
        local elapsed=os.clock()-callbackStarted
        g_UXOfficial_ESPDiagnostics.LastCallbackCPUSeconds=elapsed
        g_UXOfficial_ESPDiagnostics.MaxCallbackCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxCallbackCPUSeconds or 0)
        g_UXOfficial_ESPDiagnostics.TotalCallbackCPUSeconds=(g_UXOfficial_ESPDiagnostics.TotalCallbackCPUSeconds or 0)+elapsed
        g_UXOfficial_ESPDiagnostics.CallbackSamples=(g_UXOfficial_ESPDiagnostics.CallbackSamples or 0)+1
    end
end


_G.g_UXOfficial_UXOfficialShotESPForceRefresh = function()
    if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken then return end
    g_UXOfficial_ESPRunnerToken.RenderDue=nil
    g_UXOfficial_ShotESP.LastScanClock = -999.0
    g_UXOfficial_ShotESP.LastTransformClock = -999.0
    local due=g_UXOfficial_ESPRunnerToken.Due
    if not due or due-g_UXOfficial_ESPNow()>0.002 then g_UXOfficial_ESPSchedule(0.001) end
end

-- Managed feature state. Source settings are data, never loaded as executable Lua.
do
    if type(_G.__LunarFeaturesCleanup) == "function" then pcall(_G.__LunarFeaturesCleanup) end
    local F = {Token={}, Diagnostics={Errors=0}, TimerClock=0, LastWorld=nil}
    _G.LunarFeatures=F
    local settings = _G.LunarFeatureSettings or {}
    _G.LunarFeatureSettings=settings
    F.Settings=settings
    local function number(value,lo,hi,fallback)
        local v=tonumber(value)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return math.floor(math.max(lo,math.min(hi,v))+0.5)
    end
    F.Clamp=number
    settings.IpadFOV=number(settings.IpadFOV or _G.LexusState.CustomTextData.IpadViewFOV,90,120,120)
    settings.AimSpeed=number(settings.AimSpeed,100,120,100)
    settings.AimTarget=number(settings.AimTarget,1,3,1)
    settings.AimEnabled=settings.AimEnabled==true
    settings.Aim2Enabled=settings.Aim2Enabled==true
    settings.MortarEnabled=settings.MortarEnabled==true
    -- Discard values retained by older hot-reloaded copies.
    settings.WallEnabled=settings.WallEnabled==true
    settings.WallVisible=number(settings.WallVisible,1,7,1)
    settings.WallOccluded=number(settings.WallOccluded,1,7,2)
    _G.g_Botmater_ESPOptions=nil;_G.g_Botmater_UXOfficialShotESP=nil
    local paths=g_UXOfficial_ESPSettingsPaths()
    for i,path in ipairs(paths) do paths[i]=path:gsub("UXOfficial_UMG_ESP_settings.lua$","UXOfficial_FEATURES_V3_settings.lua") end
    if io and io.open then
        for _,path in ipairs(paths) do
            local ok,file=pcall(io.open,path,"r")
            if ok and file then
                local readOK,payload=pcall(function() return file:read("*a") end)
                pcall(function() file:close() end)
                if readOK and type(payload)=="string" then
                    F.SettingsReadPath=path
                    for _,key in ipairs({"AimEnabled","IpadEnabled","Aim2Enabled","MortarEnabled","WallEnabled"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then
                            if key=="IpadEnabled" then _G.LexusConfig.IpadView=val=="true" else settings[key]=val=="true" end
                        end
                    end
                    for _,key in ipairs({"IpadFOV","AimSpeed","AimTarget","WallVisible","WallOccluded"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,key=="IpadFOV" and 90 or (key=="AimSpeed" and 100 or 1),(key=="AimTarget" and 3 or (key=="WallVisible" or key=="WallOccluded") and 7 or 120),settings[key]) end
                    end
                    for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do
                        local val=payload:match("%f[%w_]V2_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_UXOfficial_ESPOptions[key]=val=="true" end
                    end
                    break
                end
            end
        end
    end
    if not F.SettingsReadPath and g_UXOfficial_ESPLoadedSettingsPath then
        F.SettingsReadPath=g_UXOfficial_ESPLoadedSettingsPath:gsub("UXOfficial_UMG_ESP_settings%.lua$","UXOfficial_FEATURES_V3_settings.lua")
    end
    settings.WallVisible=number(settings.WallVisible,1,7,1)
    settings.WallOccluded=number(settings.WallOccluded,1,7,2)
    if settings.Aim2Enabled then settings.AimEnabled=false end
    _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
    F.Now=function()
        local now=nil
        pcall(function()
            local world=g_UXOfficial_ESPWorld()
            if world and GameplayStaticsESP and GameplayStaticsESP.GetRealTimeSeconds then now=GameplayStaticsESP.GetRealTimeSeconds(world) end
        end)
        return tonumber(now) or F.TimerClock
    end
    F.Save=function(force)
        if not F.Dirty or not io or not io.open then return end
        local lines={"return {", "  IpadEnabled = "..tostring(_G.LexusConfig.IpadView==true)..","}
        for _,key in ipairs({"AimEnabled","Aim2Enabled","MortarEnabled","WallEnabled","WallVisible","WallOccluded","IpadFOV","AimSpeed","AimTarget"}) do lines[#lines+1]="  "..key.." = "..tostring(settings[key]).."," end
        for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter","Radar"}) do lines[#lines+1]="  V2_"..key.." = "..tostring(_G.g_UXOfficial_ESPOptions[key]==true).."," end
        lines[#lines+1]="}"
        local payload=table.concat(lines,"\n")
        local savePaths=F.SettingsReadPath and {F.SettingsReadPath} or paths
        for _,path in ipairs(savePaths) do
            local wrote,reason,atomic=g_UXOfficial_ESPWriteSettings(path,payload)
            if wrote then
                F.SettingsReadPath=path;F.Dirty=false;F.Diagnostics.LastSaveOK=true;F.Diagnostics.LastSavePath=path;F.Diagnostics.AtomicSave=atomic
                return true
            end
            F.Diagnostics.LastSaveError=reason
        end
        F.Diagnostics.LastSaveOK=false
        return false
    end
    F.MarkDirty=function(immediate) F.Dirty=true;if immediate then F.Save(true) end end
    F.SetIpad=function(enabled)
        _G.LexusConfig.IpadView=enabled==true or enabled==1
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_UXOfficial_ApplyiPadView)
        F.MarkDirty(true)
    end
    F.SetIpadFOV=function(value)
        settings.IpadFOV=number(value,90,120,120)
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_UXOfficial_ApplyiPadView)
        F.MarkDirty()
    end
    F.SetAimSpeed=function(value)
        local previousSpeed=settings.AimSpeed
        settings.AimSpeed=number(value,100,120,100)
        if settings.AimSpeed~=previousSpeed then
            F.AimLastClock=nil;F.AimDue=0
            if _G.XthrlenState then _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0 end
        end
        if _G.XthrlenState and _G.XthrlenState.CustomTextData then
            local data=_G.XthrlenState.CustomTextData
            data.AimTouchHipSpeed=settings.AimSpeed
            data.AimTouchScopeSpeed=settings.AimSpeed
        end
        F.MarkDirty()
    end
    F.SetAimTarget=function(value) settings.AimTarget=number(value,1,3,1);F.MarkDirty(true) end
    -- ItemBase supports caller-owned event keys. Both native switches subscribe
    -- through its normal lifecycle; there are no saved widget references.
    F.AimSettingsEventType=-14050701
    F.AimSettingsEventID=1
    F.SetAimMode=function(value)
        local mode=F.Clamp(value,0,2,0)
        local changed=settings.AimEnabled~=(mode==1) or settings.Aim2Enabled~=(mode==2)
        settings.AimEnabled=mode==1
        settings.Aim2Enabled=mode==2
        _G.XthrlenConfig.AimTouchEnable=settings.AimEnabled
        if not settings.AimEnabled then
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
        end
        if not settings.Aim2Enabled and F.Aim2 then F.Aim2.Stop() end
        if F.Aim2 then F.Aim2.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
        if changed and EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.AimSettingsEventType,F.AimSettingsEventID)
            if not ok then F.Error("Aim.SettingsRefresh",err) end
        end
    end
    F.SetAim=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 1 or (settings.Aim2Enabled and 2 or 0))
    end
    F.SetAim2=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 2 or (settings.AimEnabled and 1 or 0))
    end
    F.SetMortar=function(enabled)
        settings.MortarEnabled=enabled==true or enabled==1
        if not settings.MortarEnabled and F.Mortar then F.Mortar.Stop() end
        if F.Mortar then F.Mortar.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end

    -- Single, unchanged ESP V2 option group.
    local v2Keys={"Name","Line","Box","Health","Distance","Skeleton","Counter","Radar"}
    local v2Valid={Name=true,Line=true,Box=true,Health=true,Distance=true,Skeleton=true,Counter=true,Radar=true}
    F.ESPSettingsEventType=-14050701
    F.ESPSettingsEventID=2
    local function commitESP(changed)
        if not changed then
            if F.Dirty then return F.Save(true) end
            return true
        end
        F.MarkDirty(true)
        _G.g_UXOfficial_UXOfficialShotESPForceRefresh()
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.ESPSettingsEventType,F.ESPSettingsEventID)
            if not ok then F.Error("ESP.SettingsRefresh",err) end
        end
        return true
    end
    F.SetESP=function(version,key,value)
        if version~=2 or not v2Valid[key] then return false end
        local on=value==true or value==1
        local options=_G.g_UXOfficial_ESPOptions
        local changed=options[key]~=on
        if changed then options[key]=on end
        if key=="Radar" and not on then g_UXOfficial_ShotESP.RadarOpen=false end
        return commitESP(changed)
    end
    F.GetESPAll=function(version)
        if version~=2 then return false end
        local options=_G.g_UXOfficial_ESPOptions
        for _,key in ipairs(v2Keys) do if options[key]~=true then return false end end
        return true
    end
    F.SetESPAll=function(version,value)
        if version~=2 then return false end
        local options=_G.g_UXOfficial_ESPOptions
        local on=value==true or value==1
        local changed=false
        for _,key in ipairs(v2Keys) do
            if options[key]~=on then options[key]=on;changed=true end
        end
        return commitESP(changed)
    end
    -- Native OnSelected skips SetFunc when the same index is selected again.
    -- Bulk command rows must still apply to partial ESP state. Only these marked
    -- rows receive the additional click callback; every other native row is untouched.
    F.InstallNativeBulkSwitch=function(class)
        if type(class)~="table" or type(class.OnSelected)~="function" then return false end
        if class.__LunarBulkSwitchV7 then return true end
        local original=class.OnSelected
        class.OnSelected=function(self,index)
            local data=self.Data
            local repeatBulk=data and data.LunarBulk and self.UIRoot.Selector:GetSelectedIndex()==index
            local result=original(self,index)
            if repeatBulk then return data.SetFunc(data.Key,self:_IndexToValue(index)) end
            return result
        end
        class.__LunarBulkSwitchV7=true
        return true
    end
    F.SetV2=function(key,value) return F.SetESP(2,key,value) end

    -- [VIPGROUP  MERGE] Wall controls update the original UI state.
    F.SetWall=function(value)
      local on=value==true or value==1
      if settings.WallEnabled==on then return true end
      settings.WallEnabled=on
      if not on and F.Wall then F.Wall.Stop() end
      if F.Wall then F.Wall.Due=0 end
      F.MarkDirty(true)
      if F.Wake then F.Wake() end
      return true
    end
    F.SetWallColor=function(key,value)
      if key~="WallVisible" and key~="WallOccluded" then return false end
      local n=number(value,1,7,settings[key])
      settings[key]=n
      if F.Wall then F.Wall.UpdateColors();F.Wall.Due=0 end
      F.MarkDirty(true)
      if settings.WallEnabled and F.Wake then F.Wake() end
      return true
    end
    F.Error=function(area,err)
        F.Diagnostics.Errors=F.Diagnostics.Errors+1
        F.Diagnostics.LastError=area..": "..tostring(err)
    end
    _G.__LunarFeaturesCleanup=function()
        F.Token.Stopped=true
        if F.Wall then F.Wall.Stop() end
        if F.Aim2 then F.Aim2.Stop() end
        if F.Mortar then F.Mortar.Stop() end
    end
end

-- [VIPGROUP  MERGE] Original-style chams: cached DrawDyeing / Highlight / IdeaOutline.
-- The existing ESP scheduler drives this; no new Wall timer.
do
    local F=_G.LunarFeatures
    local valid=g_UXOfficial_ESPValid
    local classes={}
    for _,name in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
        local ok,value=pcall(import,name)
        if ok and value then classes[#classes+1]=value end
    end
    local W={Meshes={},Pawns={},LastTick=-999,LastCleanup=-999,CleanupInterval=1/60,ConsoleWorld=nil,Applied=0}
    F.Wall=W
    local properties={
        {"SetDrawDyeing","bDrawDyeing"},{"SetDrawHighlight","bDrawHighlight"},
        {"SetDrawIdeaOutline","bDrawIdeaOutline"},{"SetRenderCustomDepth","bRenderCustomDepth"}
    }
    local function calls(vis,occ)
        return {
            {"SetDrawDyeing",true},{"SetDrawDyeingMode",1},{"SetVisibleDyeingColor",vis},{"SetOccludedDyeingColor",occ},
            {"SetDyeingColorFadeDistance",99999.0},{"SetDyeingColorMinMaxDistance",0.0,99999.0},
            {"SetDrawHighlight",true},{"OverrideHighlightColor",vis},{"SetHighlightCanBeOccluded",false},
            {"SetDrawIdeaOutline",true},{"SetIdeaOutlineNew",true},{"SetIdeaOutlineOcclusionHighlight",true},
            {"OverrideIdeaOutlineColor",vis},{"SetIdeaOutlineOcclusionColor",occ},{"OverrideIdeaOutlineThickness",20.0},
            {"SetIdeaOverrideOutlineAndOcclusion",true},{"SetRenderCustomDepth",true},{"SetCustomDepthStencilValue",255}
        }
    end
    -- Wall shader colors retain the working intensity 100 and alpha 100.
    -- Slot 6 uses the supplied saffron RGB (100,1,0); slot 7 is red.
    local palette={{100,0,35},{100,100,100},{0,100,100},{0,100,0},
        {100,100,0},{100,1,0},{100,0,0}}
    W.Palette=palette
    local colorCalls
    W.UpdateColors=function()
        local a=palette[F.Settings.WallVisible] or palette[1]
        local b=palette[F.Settings.WallOccluded] or palette[2]
        local vis=g_UXOfficial_ESPColor(a[1],a[2],a[3],100)
        local occ=g_UXOfficial_ESPColor(b[1],b[2],b[3],100)
        colorCalls=calls(vis,occ)
        W.LastTick=-999
    end
    W.UpdateColors()
    local function invoke(mesh,call)
        local method=mesh[call[1]]
        if not method then return end
        if call[3]~=nil then method(mesh,call[2],call[3]) else method(mesh,call[2]) end
    end
    local function restore(mesh,state)
        if not valid(mesh) then return end
        for _,pair in ipairs(properties) do
            pcall(function() if mesh[pair[1]] then mesh[pair[1]](mesh,state[pair[2]]==true) end end)
        end
    end
    W.Stop=function()
        for mesh,state in pairs(W.Meshes) do restore(mesh,state) end
        W.Meshes={};W.Pawns={}
        W.LastTick=-999;W.LastCleanup=-999
    end
    local function relevant(pawn,myLocation,maxRange,pc)
        local entry=ESPShared.GetFrameRecord(pawn)
        return entry.Alive and ESPShared.InRange(entry,myLocation,maxRange)
            and pc and ESPShared.ProbeActor(pc,pawn).OnScreen
    end
    W.Cleanup=function(myLocation,maxRange,pc)
        for pawn,meshes in pairs(W.Pawns) do
            if not relevant(pawn,myLocation,maxRange,pc) then
                for mesh in pairs(meshes) do
                    local state=W.Meshes[mesh]
                    if state then restore(mesh,state);W.Meshes[mesh]=nil end
                end
                W.Pawns[pawn]=nil
            end
        end
    end
    local function apply(mesh,pawn,seen)
        if not valid(mesh) or seen[mesh] then return end
        seen[mesh]=true
        local original=W.Meshes[mesh]
        if not original then
            original={}
            for _,pair in ipairs(properties) do pcall(function() original[pair[2]]=mesh[pair[2]]==true end) end
            W.Meshes[mesh]=original
        end
        if original.Pawn and original.Pawn~=pawn then
            local old=W.Pawns[original.Pawn]
            if old then old[mesh]=nil;if next(old)==nil then W.Pawns[original.Pawn]=nil end end
        end
        original.Pawn=pawn
        local owned=W.Pawns[pawn]
        if not owned then owned={};W.Pawns[pawn]=owned end
        owned[mesh]=true
        -- Each protected setter is attempted independently. An unavailable optional
        -- extension does not prevent other reference rendering modes from applying.
        for _,call in ipairs(colorCalls) do
            local ok,err=pcall(invoke,mesh,call)
            if not ok then F.Error("Wall."..call[1],err) end
        end
        W.Applied=W.Applied+1
    end
    W.Tick=function(now,me,pc)
        if not F.Settings.WallEnabled then return end
        now=now or F.Now()
        me=me or g_UXOfficial_ESPGetLocalCharacter()
        pc=pc or g_UXOfficial_ESPGetController()
        if not valid(me) or not valid(pc) then W.Stop() return end
        local maxRange=tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters) or 450.0
        if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
        local myLocation=ESPShared.GetFrameRecord(me).Location
        if now<W.LastCleanup or now-W.LastCleanup>=W.CleanupInterval-0.000001 then
            W.Cleanup(myLocation,maxRange,pc);W.LastCleanup=now
        end
        if now>=W.LastTick and now-W.LastTick<0.30-0.000001 then return end
        W.LastTick=now
        local world=g_UXOfficial_ESPWorld()
        if world~=W.ConsoleWorld then
            local ok=pcall(function()
                if not world or not UKismetSystemLibrary.ExecuteConsoleCommand then return end
                for _,command in ipairs({"r.EnableDrawDyeingColor 1","r.CustomDepth 3","r.IdeaOutline.Enable 1","r.Highlight.Enable 1"}) do
                    UKismetSystemLibrary.ExecuteConsoleCommand(world,command)
                end
            end)
            if ok and world then W.ConsoleWorld=world end
        end
        local pawns=ESPShared.GetFramePawns()
        if not pawns then return end
        local seen={}
        local myTeam=me.TeamID or 0
        for _,pawn in pairs(pawns) do
            if valid(pawn) and pawn~=me and pawn.TeamID~=myTeam and relevant(pawn,myLocation,maxRange,pc) then
                pcall(function() apply(pawn.Mesh,pawn,seen) end)
                local avatar=nil
                pcall(function()
                    avatar=pawn.CharacterAvatarComp2_BP
                    if not avatar and pawn.getAvatarComponent2 then avatar=pawn:getAvatarComponent2() end
                end)
                if avatar and avatar.GetMeshCompBySlot then
                    for slot=0,7 do pcall(function() apply(avatar:GetMeshCompBySlot(slot),pawn,seen) end) end
                end
                for _,class in ipairs(classes) do
                    pcall(function()
                        if not pawn.GetComponentsByClass then return end
                        local components=pawn:GetComponentsByClass(class)
                        if components then for i=0,components:Num()-1 do apply(components:Get(i),pawn,seen) end end
                    end)
                end
                pcall(function()
                    local weapon=pawn.GetCurrentWeapon and pawn:GetCurrentWeapon()
                    if valid(weapon) then apply(weapon.Mesh,pawn,seen) end
                end)
            end
        end
        for mesh,state in pairs(W.Meshes) do
            if not seen[mesh] then
                restore(mesh,state);W.Meshes[mesh]=nil
                local owned=W.Pawns[state.Pawn]
                if owned then owned[mesh]=nil;if next(owned)==nil then W.Pawns[state.Pawn]=nil end end
            end
        end
    end
    _G.StartWallhack=function() F.SetWall(true) end
    _G.StopWallhack=function() F.SetWall(false) end
end


do
local AimV2,AimGameplayStatics,AimMath,AimUI
pcall(function() AimV2=import("Vector2D") end)
pcall(function() AimGameplayStatics=import("GameplayStatics") end)
pcall(function() AimMath=import("KismetMathLibrary") end)
pcall(function() AimUI=require("client.common.ui_util") end)
_G.XthrlenConfig = _G.XthrlenConfig or {}
_G.XthrlenState = _G.XthrlenState or {}
_G.XthrlenState.CustomTextData = _G.XthrlenState.CustomTextData or {}

_G.XthrlenConfig.AimTouchEnable        = _G.LunarFeatures.Settings.AimEnabled
_G.XthrlenConfig.AimTouchHipfire       = true
_G.XthrlenConfig.AimTouchScopeAll      = true
_G.XthrlenConfig.AimTouchHipVisCheck   = true
_G.XthrlenConfig.AimTouchScopeVisCheck = true
_G.XthrlenConfig.AimTouchHipIgKnock    = true
_G.XthrlenConfig.AimTouchScopeIgKnock  = true

_G.XthrlenConfig.AimTouchHipIgBot      = false
_G.XthrlenConfig.AimTouchScopeIgBot    = false
_G.XthrlenConfig.AimTouchSG            = false
_G.XthrlenConfig.AimTouchSGAutoFire    = false
_G.XthrlenConfig.AimTouchScopeSniper   = false
_G.XthrlenConfig.AimTouchMortar        = false
_G.XthrlenConfig.EspFovCircle          = false

_G.XthrlenState.CustomTextData.AimTouchHipPrio    = 1
_G.XthrlenState.CustomTextData.AimTouchHipBone    = 1
_G.XthrlenState.CustomTextData.AimTouchHipCond    = 1
_G.XthrlenState.CustomTextData.AimTouchHipSpeed   = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchHipDist    = 120
_G.XthrlenState.CustomTextData.AimTouchHipFOV     = 30

_G.XthrlenState.CustomTextData.AimTouchScopePrio   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeBone   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeCond   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchScopeDist   = 120
_G.XthrlenState.CustomTextData.AimTouchScopeFOV    = 30
_G.XthrlenState.CustomTextData.AimTouchScopePred   = 0

_G.XthrlenState.offPitch = _G.XthrlenState.offPitch or 0
_G.XthrlenState.offYaw   = _G.XthrlenState.offYaw   or 0

local function clampAngles(angles)
    if angles.Pitch > 180 then angles.Pitch = angles.Pitch - 360 end
    if angles.Pitch < -180 then angles.Pitch = angles.Pitch + 360 end

    if angles.Pitch < -75 then
        angles.Pitch = -75
    elseif angles.Pitch > 75 then
        angles.Pitch = 75
    end

    while angles.Yaw < -180 do angles.Yaw = angles.Yaw + 360 end
    while angles.Yaw > 180  do angles.Yaw = angles.Yaw - 360 end

    return angles
end

_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not (slua and slua.isValid and slua.isValid(player)) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    local ok,err=pcall(function()
        if not _G.XthrlenConfig.AimTouchEnable then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not (slua and slua.isValid and slua.isValid(player)) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not (slua and slua.isValid and slua.isValid(pc)) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        -- Both supplied hip/scope modes require firing. Return before scanning,
        -- weapon classification, visibility checks or imports during idle play.
        if not isFiring then return end
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        if _G.LunarFeatures.Settings.MortarEnabled and weapon and weapon.MortarState==2 then return end
        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.XthrlenState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.XthrlenState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 100
        local fovVal = 30
        local maxDistMeters = 100
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0 

        if isMortar and _G.XthrlenConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.XthrlenState.CustomTextData.AimTouchMortarFOV or 360 
            maxDistMeters = 2000 
            useVisCheck = false 
            igKnock = false
            igBot = false
            predVal = _G.XthrlenState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.XthrlenConfig.AimTouchSG then
            cond = _G.XthrlenState.CustomTextData.AimTouchSGCond or 1
            if _G.XthrlenConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.XthrlenState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.XthrlenState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.XthrlenState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.XthrlenConfig.AimTouchSGVisCheck
            igKnock = _G.XthrlenConfig.AimTouchSGIgKnock
            igBot = _G.XthrlenConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.XthrlenConfig.AimTouchScopeSniper then
                cond = _G.XthrlenState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.XthrlenState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.XthrlenState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.XthrlenConfig.AimTouchSniperVisCheck
                igKnock = _G.XthrlenConfig.AimTouchSniperIgKnock
                igBot = _G.XthrlenConfig.AimTouchSniperIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.XthrlenConfig.AimTouchScopeAll then
                cond = _G.XthrlenState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchScopeSpeed or 100
                fovVal = _G.XthrlenState.CustomTextData.AimTouchScopeFOV or 30
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchScopeDist or 100
                useVisCheck = _G.XthrlenConfig.AimTouchScopeVisCheck
                igKnock = _G.XthrlenConfig.AimTouchScopeIgKnock
                igBot = _G.XthrlenConfig.AimTouchScopeIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchScopePred or 0
            else
                return
            end
        else
            if not _G.XthrlenConfig.AimTouchHipfire then return end
            cond = _G.XthrlenState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.XthrlenState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = 1
            speedVal = _G.XthrlenState.CustomTextData.AimTouchHipSpeed or 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.XthrlenConfig.AimTouchHipVisCheck
            igKnock = _G.XthrlenConfig.AimTouchHipIgKnock
            igBot = _G.XthrlenConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = AimV2
        local UGameplayStatics = AimGameplayStatics
        local KismetMathLibrary = AimMath
        if not FVector2D or not UGameplayStatics or not KismetMathLibrary then return end
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = AimUI
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selected=_G.LunarFeatures.Settings.AimTarget
        boneIdx=selected==2 and 2 or (selected==3 and 5 or 1)
        local selBoneName=selected==2 and "spine_03" or (selected==3 and "calf_l" or "head")

        for i, target in ipairs(enemies) do
            repeat
            if not slua.isValid(target) then break end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then break end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then break end
            end
            
            if useVisCheck then
                local curTime = _G.LunarFeatures.Now()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or curTime < _G.AimTouchVisCache[tId].time or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then break end
            end
            
            local tPos = target.GetBonePos and target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20
                        elseif boneIdx == 5 then tPos.Z = tPos.Z - 60 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then break end
            
            local screen = FVector2D()
            local success,outScreen = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if outScreen then screen=outScreen end
            if not success or screen.X <= 0 or screen.Y <= 0 then break end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then break end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            until true
        end
        
        local cache=_G.AimTouchVisCache
        local clock=_G.LunarFeatures.Now()
        if cache and (not _G.LunarFeatures.AimPruneDue or clock>=_G.LunarFeatures.AimPruneDue) then
            for key,entry in pairs(cache) do if clock<entry.time or clock-entry.time>1 then cache[key]=nil end end
            _G.LunarFeatures.AimPruneDue=clock+0.5
        end
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget.GetBonePos and bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20
                    elseif boneIdx == 5 then finalBonePos.Z = finalBonePos.Z - 60 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if not isMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        if isADS and isFiring then
            local dist = player:GetDistanceTo(bestTarget) / 100.0
            finalBonePos.Z = finalBonePos.Z - (dist * 1.1)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        if not isADS then
            _G.XthrlenState.offPitch = 0
            _G.XthrlenState.offYaw   = 0
        end

        local dPitch = rot.Pitch - currentRot.Pitch
        local dYaw   = rot.Yaw   - currentRot.Yaw

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                dYaw   = dYaw   - (camRot.Yaw   - currentRot.Yaw)
                dPitch = dPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if dPitch~=dPitch or dYaw~=dYaw or math.abs(dPitch)==math.huge or math.abs(dYaw)==math.huge then return end
        dPitch=(dPitch+180)%360-180
        dYaw=(dYaw+180)%360-180

        -- Displayed settings remain 100..120. The requested maximum applies
        -- at most half the previous full correction; low settings are gentler.
        local now=_G.LunarFeatures.Now()
        local previous=_G.LunarFeatures.AimLastClock
        local dt=previous and math.max(0.001,math.min(0.05,now-previous)) or 0.011
        _G.LunarFeatures.AimLastClock=now
        local normalized=(_G.LunarFeatures.Clamp(speedVal,100,120,100)-100)/20.0
        local strength=0.02+0.48*normalized*normalized
        local alpha=math.min(0.5,1.0-(1.0-strength)^(dt/0.011))
        local maxTurnRate=10.0+35.0*normalized

        -- Camera-relative ADS error already accounts for view/controller offset.
        -- Repeatedly accumulating target error causes windup and unwanted swipes.
        _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
        local apply={Pitch=currentRot.Pitch+dPitch,Yaw=currentRot.Yaw+dYaw,Roll=0}

        local pitchDelta=(apply.Pitch-currentRot.Pitch+180)%360-180
        local yawDelta=(apply.Yaw-currentRot.Yaw+180)%360-180
        local pitchStep,yawStep=pitchDelta*alpha,yawDelta*alpha
        local stepLength=math.sqrt(pitchStep*pitchStep+yawStep*yawStep)
        local stepLimit=maxTurnRate*dt
        if stepLength>stepLimit then
            local scale=stepLimit/stepLength
            pitchStep=pitchStep*scale;yawStep=yawStep*scale
        end
        local out={Pitch=currentRot.Pitch+pitchStep,Yaw=currentRot.Yaw+yawStep,Roll=0}

        out = clampAngles(out)
        pc:SetControlRotation(out, "AimTouch")
    end)
    if not ok then _G.LunarFeatures.Error("Aim",err) end
end



_G.LunarFeatures.Aim={Tick=_G.AimTouch}
end

-- Controls live entirely in the native game settings page.

-- Additional aim modes share the managed scheduler. No timer is created here.
do
    local F=_G.LunarFeatures
    local MathLib,Layout,HealthStates,PawnStates
    pcall(function() MathLib=import("KismetMathLibrary") end)
    pcall(function() Layout=import("WidgetLayoutLibrary") end)
    pcall(function() HealthStates=import("ECharacterHealthStatus") end)
    pcall(function() PawnStates=import("EPawnState") end)
    local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
    local function get(obj,key)
        if not obj then return nil end
        local ok,v=pcall(function() return obj[key] end)
        if ok then return v end
    end
    local function call(obj,key,...)
        local method=get(obj,key)
        if type(method)~="function" then return nil end
        local ok,v=pcall(method,obj,...)
        if ok then return v end
    end
    local function valid(obj) return obj and g_UXOfficial_ESPValid(obj) end
    local function pos(v)
        if v and finite(v.X) and finite(v.Y) and finite(v.Z) then return {X=v.X,Y=v.Y,Z=v.Z} end
    end
    local function nativeVector(v) return g_UXOfficial_ESPV3(v.X,v.Y,v.Z) end
    local function team(actor)
        local id=call(actor,"GetTeamID") or get(actor,"TeamID")
        if id==nil then
            local state=call(actor,"GetPlayerStateSafety")
            id=call(state,"GetTeamID") or get(state,"TeamID")
        end
        return id
    end
    local function dead(actor)
        if not valid(actor) then return true end
        local hp=call(actor,"GetHealth") or get(actor,"Health") or get(actor,"HP")
        if finite(hp) and hp<=0 then return true end
        if get(actor,"bIsDead")==true or get(actor,"bDead")==true or get(actor,"bIsDeadFlag")==true then return true end
        if HealthStates and HealthStates.FinishedLastBreath~=nil and get(actor,"HealthStatus")==HealthStates.FinishedLastBreath then return true end
        if PawnStates and PawnStates.Dead~=nil and call(actor,"HasPawnState",PawnStates.Dead)==true then return true end
        return false
    end
    local function weapon(player)
        local w=call(player,"GetCurrentWeapon") or get(player,"CurrentWeapon")
        if not valid(w) then
            local wm=get(player,"WeaponManagerComponent")
            w=get(wm,"CurrentWeaponReplicated") or get(wm,"CurrentWeapon")
        end
        return valid(w) and w or nil
    end
    local function kind(w)
        local name=call(w,"GetWeaponName")
        if type(name)~="string" or not name:find("%S") then return "unknown" end
        name=name:lower()
        if name:find("mortar",1,true) or name:find("cối",1,true) or name:find("cỐi",1,true) then return "mortar" end
        return "other"
    end
    local function context()
        local pc=g_UXOfficial_ESPGetController()
        local player=g_UXOfficial_ESPGetLocalCharacter()
        if valid(pc) and not dead(player) then return g_UXOfficial_ESPWorld(),pc,player,weapon(player) end
    end
    local function pelvis(actor)
        local p=pos(call(actor,"GetBonePos","pelvis",{X=0,Y=0,Z=0}))
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"GetSocketLocation","pelvis")) end
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"K2_GetActorLocation")) end
        return p
    end
    local function allPlayers()
        local list
        pcall(function() if GameplayData.GetAllPlayerCharacters then list=GameplayData.GetAllPlayerCharacters() end end)
        return type(list)=="table" and list or {}
    end
    local function viewport(pc)
        local w,h=g_UXOfficial_ESPViewport(pc)
        if not finite(w) or w<=0 or not finite(h) or h<=0 then return 1920,1080 end
        return w,h
    end
    local function project(pc,p)
        local screen=FVector2D(0,0)
        local ok,yes=pcall(function() return pc:ProjectWorldLocationToScreen(nativeVector(p),screen,false) end)
        if ok and (yes==true or yes==1) and finite(screen.X) and finite(screen.Y) then return screen.X,screen.Y end
    end
    local function camera(pc,player,fallback)
        local cm=call(pc,"GetPlayerCameraManager")
        if not valid(cm) then pcall(function() cm=GameplayStaticsESP.GetPlayerCameraManager(pc,0) end) end
        return pos(call(cm,"GetCameraLocation")) or fallback or pos(call(player,"K2_GetActorLocation"))
    end
    local function rotation(pc,target,source)
        if not target or not finite(target.Pitch) or not finite(target.Yaw) or not finite(target.Roll) then return false end
        local current=call(pc,"GetControlRotation")
        if current and finite(current.Pitch) and finite(current.Yaw) and finite(current.Roll or 0)
            and math.abs((target.Pitch-current.Pitch+180)%360-180)<0.00001
            and math.abs((target.Yaw-current.Yaw+180)%360-180)<0.00001
            and math.abs(target.Roll-(current.Roll or 0))<0.00001 then return true end
        local ok,accepted=pcall(function() return pc:SetControlRotation(target,source) end)
        if not ok then F.Error(source,accepted) end
        return ok and accepted~=false
    end
    -- A failed restore survives a script reload and remains eligible for retry.
    local pending=_G.__LunarAim2RestorePending or {}
    _G.__LunarAim2RestorePending=pending
    local A={Target=nil,Enabled=false,Due=0,LastTime=nil,Records=pending,RestoreErrors={}}
    F.Aim2=A
    local fields={"RecoilKickADS","GameDeviationFactor","GameDeviationAccuracy"}
    local function restore()
        for obj,record in pairs(A.Records) do
            if not valid(obj) then A.Records[obj]=nil;A.RestoreErrors[obj]=nil
            else
                for key,value in pairs(record) do
                    local ok,err=true,nil
                    if get(obj,key)~=value then ok,err=pcall(function() obj[key]=value end) end
                    if ok and get(obj,key)==value then record[key]=nil
                    elseif not A.RestoreErrors[obj] or not A.RestoreErrors[obj][key] then
                        A.RestoreErrors[obj]=A.RestoreErrors[obj] or {};A.RestoreErrors[obj][key]=true
                        F.Error("Aim2.Restore."..key,err or "native field did not accept restoration")
                    end
                end
                if next(record)==nil then A.Records[obj]=nil;A.RestoreErrors[obj]=nil end
            end
        end
    end
    function A.Stop()
        restore();A.Target=nil;A.Enabled=false;A.LastTime=nil;A.World=nil;A.PC=nil;A.Player=nil;A.Weapon=nil;A.Entity=nil;A.Due=0;A.Unsupported=nil;A.ApplyFailed=nil
    end
    function A.NextInterval(now)
        if not F.Settings.Aim2Enabled then return 0.5 end
        return math.max(0.001,A.Due-(finite(now) and now or F.Now()))
    end
    local function hard(entity)
        if not valid(entity) then return end
        local record=A.Records[entity]
        if not record then record={};A.Records[entity]=record end
        for _,key in ipairs(fields) do
            local current=get(entity,key)
            if finite(current) then
                if record[key]==nil then record[key]=current end
                if current~=0.01 then
                    local ok,err=pcall(function() entity[key]=0.01 end)
                    if not ok and (not A.ApplyFailed or not A.ApplyFailed[key]) then
                        A.ApplyFailed=A.ApplyFailed or {};A.ApplyFailed[key]=true;F.Error("Aim2.Apply."..key,err)
                    end
                end
            elseif not A.Unsupported or not A.Unsupported[key] then
                A.Unsupported=A.Unsupported or {};A.Unsupported[key]=true
                F.Error("Aim2.Unsupported",key.." is unreadable; left unchanged")
            end
        end
    end
    function A.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.Aim2Enabled then if A.Player or next(A.Records) then A.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)=="mortar" then A.Stop();A.Due=now+0.5;return false end
        local entity=get(w,"ShootWeaponEntityComp")
        if A.World~=world or A.PC~=pc or A.Player~=player or A.Weapon~=w or A.Entity~=entity then
            A.Stop();A.World=world;A.PC=pc;A.Player=player;A.Weapon=w;A.Entity=entity
        end
        if now<A.Due-0.000001 and (not A.LastTime or now>=A.LastTime) then return false end
        local dt=A.LastTime and now-A.LastTime or 0.5
        if not finite(dt) or dt<=0 then dt=0.5 end
        A.LastTime=now;A.Due=now+0.5;hard(entity)
        if get(player,"bIsWeaponAiming")~=true then A.Target=nil;A.Enabled=false;A.Due=now+0.2;return false end
        if not MathLib or not MathLib.FindLookAtRotation then return false end
        local myTeam=team(player)
        if myTeam==nil then return false end
        local width,height=viewport(pc)
        local scale=1
        pcall(function() if Layout and Layout.GetViewportScale then local s=Layout.GetViewportScale(pc);if finite(s) and s>0 then scale=s end end end)
        -- Reference circle is 150 UI units, with its inner 70% used for selection.
        local rx,ry=105*scale,105*scale
        local best,bestScore=nil,math.huge
        for _,enemy in pairs(allPlayers()) do
            if enemy~=player and not dead(enemy) then
                local enemyTeam=team(enemy)
                if enemyTeam~=nil and tostring(enemyTeam)~=tostring(myTeam) then
                    local p=pelvis(enemy)
                    if p then
                        local x,y=project(pc,p)
                        if x and x>=0 and y>=0 and x<=width and y<=height then
                            local dx,dy=(x-width/2)/rx,(y-height/2)/ry
                            local score=dx*dx+dy*dy
                            if finite(score) and score<=1 and score<bestScore then best,bestScore=enemy,score end
                        end
                    end
                end
            end
        end
        A.Target=best;A.Enabled=best~=nil
        if not best then return false end
        local loc,p=camera(pc,player),pelvis(best)
        if not loc or not p then return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(loc),nativeVector(p))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Pitch) or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local dp,dy=(desired.Pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local dist=math.sqrt(dp*dp+dy*dy)
        local step=90*math.min(dt,0.5)
        local fraction=dist>step and step/dist or 1
        local final={Pitch=current.Pitch+dp*fraction,Yaw=current.Yaw+dy*fraction,Roll=current.Roll or 0}
        local w2,pc2,p2,wCurrent=context()
        if not F.Settings.Aim2Enabled or world~=w2 or pc~=pc2 or player~=p2 or w~=wCurrent or get(player,"bIsWeaponAiming")~=true or dead(best) then A.Stop();return false end
        return rotation(pc,final,"CircleAim")
    end
    local M={Target=nil,Candidates={},ScanDue=0,Due=0,LastTime=nil,Status="inactive",ActivePlaced=false}
    F.Mortar=M
    function M.Stop()
        M.Target=nil;M.Candidates={};M.ScanDue=0;M.Due=0;M.LastTime=nil;M.World=nil;M.PC=nil;M.Player=nil;M.Weapon=nil;M.ActivePlaced=false;M.Status="inactive"
    end
    local function distance(player,target)
        local d=call(player,"GetDistanceTo",target)
        if finite(d) and d>=0 then return d end
        local a,b=pos(call(player,"K2_GetActorLocation")),pos(call(target,"K2_GetActorLocation"))
        if a and b then local dx,dy,dz=a.X-b.X,a.Y-b.Y,a.Z-b.Z;d=math.sqrt(dx*dx+dy*dy+dz*dz);if finite(d) then return d end end
    end
    local function enemy(player,target)
        if target==player or dead(target) then return false end
        local mine,theirs=team(player),team(target)
        if mine~=nil and theirs~=nil and tostring(mine)==tostring(theirs) then return false end
        local d=distance(player,target)
        return finite(d) and d<=200000
    end
    local function trajectory(launch,V,G,target)
        if not pos(launch) or not pos(target) or not finite(V) or V<=0 or not finite(G) or G<=0 then return false,45,0,0 end
        local dx=math.max(500,math.sqrt((target.X-launch.X)^2+(target.Y-launch.Y)^2)-80)
        local dy=target.Z-launch.Z
        local minVSq=G*(dy+math.sqrt(dx*dx+dy*dy))
        if not finite(dx) or not finite(minVSq) then return false,45,0,0 end
        if V*V<minVSq then V=math.sqrt(math.max(0,minVSq))+100 end
        local v2=V*V
        local root=v2*v2-G*(G*dx*dx+2*dy*v2)
        if not finite(root) or root<0 then return false,45,0,dx end
        local rad=math.atan((v2+math.sqrt(root))/(G*dx))
        local deg,tof=math.deg(rad),dx/(V*math.cos(rad))
        if finite(deg) and finite(tof) and tof>0 and deg>=35 and deg<=89.5 then return true,deg,tof,dx end
        return false,45,0,dx
    end
    local function solve(launch,target)
        local okN,aN,tN,dN=trajectory(launch,9070,2744,target)
        local okF,aF,tF,dF=trajectory(launch,12520,3920,target)
        local okU,aU,tU,dU=trajectory(launch,16800,4410,target)
        if okN and dN<=25000 then return true,aN,tN,dN end
        if okF and dF<=40000 then return true,aF,tF,dF end
        if okU then return true,aU,tU,dU end
        if okN then return true,aN,tN,dN end
        return false,45,0,dN
    end
    M.SolveTrajectory=solve
    local function predict(target,base,launch)
        local velocity=call(target,"GetVelocity")
        if not velocity or not finite(velocity.X) or not finite(velocity.Y) or math.abs(velocity.X)+math.abs(velocity.Y)<0.01 then return base end
        local predicted={X=base.X,Y=base.Y,Z=base.Z}
        local fallback
        for _=1,2 do
            local ok,a,tof,d=solve(launch,predicted)
            if not ok then break end
            fallback={ok,a,tof,d}
            if tof<=0 or tof>15 then break end
            predicted.X=base.X+velocity.X*tof;predicted.Y=base.Y+velocity.Y*tof
            if not pos(predicted) then return base end
        end
        return predicted,fallback
    end
    function M.NextInterval(now)
        if not F.Settings.MortarEnabled then return 0.5 end
        return math.max(0.001,M.Due-(finite(now) and now or F.Now()))
    end
    function M.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.MortarEnabled then if M.Player then M.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)~="mortar" or get(w,"MortarState")~=2 then
            M.Stop();M.Status="not_placed_mortar";M.Due=now+0.5;return false
        end
        if M.World~=world or M.PC~=pc or M.Player~=player or M.Weapon~=w then
            M.Stop();M.World=world;M.PC=pc;M.Player=player;M.Weapon=w
        end
        if now<M.Due-0.000001 and (not M.LastTime or now>=M.LastTime) then return false end
        M.LastTime=now;M.Due=now+0.5;M.ActivePlaced=true;M.Status="targeting"
        if not enemy(player,M.Target) then
            M.Target=nil
            if now>=M.ScanDue then M.Candidates=allPlayers();M.ScanDue=now+0.25 end
            local width,height=viewport(pc)
            local best,score=nil,math.huge
            for _,target in pairs(M.Candidates) do
                if enemy(player,target) then
                    local p=pelvis(target)
                    if p then local x,y=project(pc,p)
                        if x and x>0 and y>0 then
                            local dx,dy=x-width/2,y-height/2
                            local d=dx*dx+dy*dy
                            if finite(d) and d<score and d<=(3.6*width/2)^2 then best,score=target,d end
                        end
                    end
                end
            end
            M.Target=best
        end
        local target=M.Target
        if not target then M.Status="no_target";return false end
        local base,launch=pelvis(target),pos(call(player,"K2_GetActorLocation"))
        if not base or not launch then M.Status="position_unavailable";return false end
        launch.Z=launch.Z+50
        local predicted,fallback=predict(target,base,launch)
        local ok,angle,tof=solve(launch,predicted)
        if not ok and fallback then ok,angle,tof=fallback[1],fallback[2],fallback[3] end
        if not ok or not finite(tof) or not finite(angle) then M.Status="unreachable";return false end
        if not MathLib or not MathLib.FindLookAtRotation then M.Status="math_unavailable";return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(camera(pc,player,launch)),nativeVector(predicted))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local pitch=((angle-45)/43)*90-60
        local dp,dy=(pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local final={Pitch=current.Pitch+dp,Yaw=current.Yaw+dy,Roll=0}
        local world2,pc2,player2,w2=context()
        if not F.Settings.MortarEnabled or world2~=world or pc2~=pc or player2~=player or w2~=w or get(w,"MortarState")~=2 or not enemy(player,target) then M.Stop();return false end
        local accepted=rotation(pc,final,"MortarAim")
        M.Status=accepted and "rotation_call_accepted" or "rotation_failed"
        return accepted
    end
end

-- Remaining features share the existing ESP V2 runner; no extra timer is created.
do
    local F=_G.LunarFeatures
    local function checked(fn,area,...)
        local ok,err=pcall(fn,...)
        if not ok then F.Error(area,err) end
    end
    F.AimDue=0;F.IpadDue=0;F.SaveDue=0
    F.Pump=function(now)
        if _G.AHMADAuthActive and not _G.AHMADAuthActive() then
            if F.Wall and F.Settings.WallEnabled then pcall(F.Wall.Stop) end
            return
        end
        F.TimerClock=g_UXOfficial_ShotESP.TimerClock
        now=now or F.Now()
        if F.Wall and F.Settings.WallEnabled then
            if _G.LicenseValid==true and (not F.Wall.Due or now>=F.Wall.Due) then
                checked(F.Wall.Tick,"Wall.Tick",now)
                F.Wall.Due=now+0.30
            end
        end
        local welcome=_G.LunarWelcomeRuntime
        if welcome and welcome.NeedsUpdate and
            (not F.WelcomeDue or now>=F.WelcomeDue or now<(F.WelcomeLastClock or now)) then
            checked(welcome.Update,"Welcome.Update")
            F.WelcomeDue=now+0.5;F.WelcomeLastClock=now
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
        local world=g_UXOfficial_ESPWorld()
        local pc=g_UXOfficial_ESPGetController()
        local pawn=g_UXOfficial_ESPGetLocalCharacter()
        if world~=F.LastWorld or pc~=F.LastPC or pawn~=F.LastPawn then
            checked(F.Aim2.Stop,"Aim2.Reset")
            checked(F.Mortar.Stop,"Mortar.Reset")
            _G.AimTouchVisCache={}
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
            F.AimLastClock=nil
            F.AimDue=0;F.IpadDue=0
            F.LastWorld,F.LastPC,F.LastPawn=world,pc,pawn
        end
        if not pc or not pawn then
            if F.Aim2.Player or next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.NoPlayer") end
            if F.Mortar.Player then checked(F.Mortar.Stop,"Mortar.NoPlayer") end
            return
        end
        if F.Settings.Aim2Enabled and
            (now>=F.Aim2.Due-0.000001 or (F.Aim2.LastTime and now<F.Aim2.LastTime)) then
            checked(F.Aim2.Tick,"Aim2.Tick")
        elseif not F.Settings.Aim2Enabled and next(F.Aim2.Records) and now>=(F.Aim2RestoreDue or 0) then
            checked(F.Aim2.Stop,"Aim2.Restore")
            F.Aim2RestoreDue=now+0.5
        end
        if F.Settings.MortarEnabled and
            (now>=F.Mortar.Due-0.000001 or (F.Mortar.LastTime and now<F.Mortar.LastTime)) then
            checked(F.Mortar.Tick,"Mortar.Tick")
        end
        if F.Settings.AimEnabled then
            if now>=F.AimDue-0.000001 or (F.AimLastTick and now<F.AimLastTick) then
                checked(F.Aim.Tick,"Aim.Render")
                F.AimLastTick=now
                F.AimDue=now+((pawn and pawn.bIsWeaponFiring) and 0.011 or 0.05)
                if not (pawn and pawn.bIsWeaponFiring) then F.AimLastClock=nil end
            end
        end
        if _G.LexusConfig.IpadView and now>=F.IpadDue then
            checked(g_UXOfficial_ApplyiPadView,"Ipad")
            F.IpadDue=now+0.5
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
    end
    F.NextInterval=function(now)
        if not F.LastPC or not F.LastPawn then return 0.50 end
        local nextDelay=0.50
        local function due(deadline) nextDelay=math.min(nextDelay,math.max(0.001,(deadline or now)-now)) end
        if F.Settings.WallEnabled and F.Wall then due(F.Wall.Due) end
        if F.Settings.AimEnabled then due(F.AimDue) end
        if F.Settings.Aim2Enabled then nextDelay=math.min(nextDelay,F.Aim2.NextInterval(now))
        elseif next(F.Aim2.Records) then due(F.Aim2RestoreDue) end
        if F.Settings.MortarEnabled then nextDelay=math.min(nextDelay,F.Mortar.NextInterval(now)) end
        if _G.LexusConfig.IpadView then due(F.IpadDue) end
        if F.Dirty then due(F.SaveDue) end
        return nextDelay
    end
    F.Wake=function()
        if F.Token.Stopped then return end
        local welcome=_G.LunarWelcomeRuntime
        if welcome and welcome.NeedsUpdate then F.WelcomeDue=0 end
        F.AimDue=0
        if F.Aim2 then F.Aim2.Due=0 end
        if F.Mortar then F.Mortar.Due=0 end
        local due=g_UXOfficial_ESPRunnerToken.Due
        if not due or due-g_UXOfficial_ESPNow()>0.002 then g_UXOfficial_ESPSchedule(0.001) end
    end
end


-- Settings maintenance uses the working reference's native timer fallbacks.
local g_UXOfficial_FastRunnerToken = {}
local previousSettingsRunner = _G.__UXOfficialShotFastRunner
if type(previousSettingsRunner) == "table" and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function() previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer) end)
end
_G.__UXOfficialShotFastRunner = g_UXOfficial_FastRunnerToken
local function g_UXOfficial_FastTick()
    if _G.__UXOfficialShotFastRunner ~= g_UXOfficial_FastRunnerToken then return end
    g_UXOfficial_EnsureHackMenu()
    local render=_G.__UXOfficialShotESPRunner
    if not render or not render.Due then pcall(g_UXOfficial_ApplyiPadView) end
end
do
    local token = g_UXOfficial_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__UXOfficialShotFastRunner ~= token then
            if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
            token.Timer = nil
            return
        end
        g_UXOfficial_FastTick()
        g_UXOfficial_StartSettingsMaintenance()
    end
    g_UXOfficial_StartSettingsMaintenance = function(owner)
        if _G.__UXOfficialShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then return true end
        if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
        token.Timer, token.Owner, token.Provider = nil, nil, nil

        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate) or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do if entry.Object == candidate then return end end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function() if GameplayData.GetPlayerController then pc = GameplayData.GetPlayerController() end end)
        if not valid(pc) then pcall(function() if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end end) end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function() return entry.Object:AddGameTimer(1.0, true, callback) end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_UXOfficial_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE" end
        else
            if package and package.loaded and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end

g_UXOfficial_EnsureHackMenu()
if _G.LunarWelcomeRuntime then _G.LunarWelcomeRuntime.NeedsUpdate=true end
g_UXOfficial_FastTick()
g_UXOfficial_StartSettingsMaintenance()
g_UXOfficial_ShotESP.Running = true
g_UXOfficial_ESPTick()

-- ============================================================================


-- Merged compatibility helpers from the supplied BRPlayerCharacterBase (10).
-- The main file remains the authoritative class and lifecycle implementation.
function BRPlayerCharacterBase:ForceGiveUp()
    if not slua or not slua.isValid or not slua.isValid(self.Object) then return false end
    local ok = pcall(function()
        self.Object.bCanNearDeathGiveup = true
        if self.Object.SetNearDeathGiveup then self.Object:SetNearDeathGiveup(true) end
        if self.Object.ServerRPC_NearDeathGiveupRescue then self.Object:ServerRPC_NearDeathGiveupRescue() end
    end)
    return ok
end

function BRPlayerCharacterBase:CheckAndEnableGiveUp()
    if not slua or not slua.isValid or not slua.isValid(self.Object) then return false end
    local ok = pcall(function()
        local obj = self.Object
        local knocked = false
        if obj.IsNearDeath then
            knocked = obj:IsNearDeath()
        elseif obj.bNearDeath then
            knocked = true
        elseif obj.PawnState then
            knocked = obj.PawnState == EPawnState.NearDeath or obj.PawnState == EPawnState.Dying
        end
        if knocked then
            obj.bCanNearDeathGiveup = true
            if obj.SetNearDeathGiveup then obj:SetNearDeathGiveup(true) end
            if obj.ClientRPC_SetShouldCheckPassWall then obj:ClientRPC_SetShouldCheckPassWall(true) end
        end
    end)
    return ok
end

-- ORIGINAL GAME CLASS AND FEATURE REGISTRATION START
-- Supplied native keys and paths appear once; existing unique additions follow.

-- [VIPGROUP  MERGE] Original skin/wardrobe module (no unrelated donor functions).
function _G.__FAHADInstallSkinCore()
-- ================= BẮT ĐẦU CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) =================
-- ==============================================================================
-- Bảng map ID phụ kiện gốc ra index mảng
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

-- DÁN ID PHỤ KIỆN CỦA BẠN VÀO BÊN TRONG NGOẶC NHỌN DƯỚI ĐÂY ↓↓↓
_G.VIP_Attachments = {
    
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    -- [ AUG Cửu Vĩ Cuồng Nộ - Dạng Cơ Bản (Màu Đỏ) ]
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},

    -- [ AUG Cửu Vĩ Cuồng Nộ - Dạng Tối Thượng (Màu Vàng) ]
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}
-- DÁN ID PHỤ KIỆN CỦA BẠN VÀO TRÊN ĐÂY ↑↑↑

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox or _G.NeedCheckDeadBoxTimer <= 0 then return end
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    -- Tối ưu: Lấy trước ID người chơi và ID súng/xe ở ngoài vòng lặp để tránh tính toán lại
    local myPlayerKey = PlayerController.PlayerKey
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            -- [FIX CHUẨN VIP]: Lấy ID của vũ khí đang cầm trên tay để xuất đúng hòm xác, Bỏ vòng lặp để chống Drop FPS
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                -- Đối chiếu với kho Skin đã lưu để lấy đúng ID Skin hiện tại
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            -- So sánh cực nhanh bằng MyPlayerKey đã cache
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        DeadBoxAvatarComponent:ResetItemAvatar()
                        DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                        DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

--[[ AddOutfit v7.5 — Tích hợp hệ thống chọn Skin qua tủ đồ (Wardrobe) ]]
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

-- Bảng ID các siêu xe (Thêm tự do nếu có ID mới)
local ITEMS = {
    -- ==============================================================================
    -- HỆ THỐNG GỐC CỦA V7.5 (KHÔNG ĐƯỢC XÓA DÒNG NÀY)
    -- ==============================================================================
    703029, 703044, 703046, 703048, 1400010, 1400062, 1400070, 1400083, 1400100, 1400106, 1400112, 1400117, 1400134, 1407917, 1400170, 
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
    1400172, 1400173, 1400174, 1400175, 1400177, 1400179, 1400180, 1400228, 1400231, 1400233, 1400236, 1400237, 1400238, 1400242, 1400244,
    202408070, 202408071, 202408072, 202408073, 202408074, 202408075,
    1407905, 1407906, 1407907, 1407908, 1407909, 1407910, 1407911, 1407912, 1407913, 1407914, 1407915, 1407916, 1410585,
    -- ==============================================================================
    -- 1. SÚNG NÂNG CẤP (CHỈ LẤY CẤP ĐỘ CAO NHẤT CỦA TỪNG KHẨU SÚNG)
    -- ==============================================================================
    -- [ M416 ]
    1101004163, -- Hoàng Gia Lộng Lẫy - M416 (Cấp 8)
    1101004201, -- Bạch Lân Nhả Ngọc - M416 (Cấp 8)
    1101004209, -- Thủy Triều Dậy Sóng - M416 (Cấp 8)
    1101004218, -- Ma Ảnh - M416 (Cấp 8)
    1101004226, -- Phong Ấn U Minh - M416 (Cấp 8)
    1101004236, -- Lam Sư Đoạt Mệnh - M416 (Cấp 8)
    1101004246, -- Hỏa Liên - M416 (Cấp 8)
    1101004046, -- Băng giá - M416 (Cấp 7)
    1101004062, -- Chú hề - M416 (Cấp 7)
    1101004078, -- Kẻ lang thang - M416 (Cấp 7)
    1101004086, -- Bò Sát Gầm Gừ - M416 (Cấp 7)
    1101004098, -- Tiếng Gọi Hoang Dã - M416 (Cấp 7)
    1101004138, -- Lõi Công Nghệ - M416 (Cấp 7)

    -- [ AKM ]
    1101001174, -- Bạo Chúa Bộ Lạc - AKM (Cấp 8)
    1101001213, -- Đô Đốc Hải Long Tinh - AKM (Cấp 8)
    1101001242, -- Ngày Phán Quyết - AKM (Cấp 8)
    1101001265, -- Thời Quang Khả Biến - AKM (Cấp 8)
    1101001276, -- Huyễn Thần - AKM (Cấp 8)
    1101001063, -- Huyền thoại Seven Seas - AKM (Cấp 7)
    1101001089, -- Băng giá - AKM (Cấp 7)
    1101001103, -- Hóa Thạch - AKM (Cấp 7)
    1101001116, -- Bí Ngô Kinh Dị - AKM (Cấp 7)
    1101001128, -- Long Vương - AKM (Cấp 7)
    1101001143, -- Hải Tặc Vàng - AKM (Cấp 7)
    1101001154, -- Người Giải Mã - AKM (Cấp 7)
    1101001231, -- Thỏ Tinh Nghịch - AKM (Cấp 7)
    1101001249, -- Thánh Quang (Trăng Thần) - AKM (Cấp 7)
    1101001256, -- Thánh Quang (Lông Vũ Hoàng Kim) - AKM (Cấp 7)
    1101001042, -- Ánh kim - AKM (Cấp 6)
    1101001068, -- Hổ gầm gừ - AKM (Cấp 5)

    -- [ SCAR-L ]
    1101003146, -- Gai Tà Ác - SCAR-L (Cấp 8)
    1101003167, -- Ma Vương Huyết Hồn - SCAR-L (Cấp 8)
    1101003227, -- Thiên Điểu - SCAR-L (Cấp 8)
    1101003057, -- Súng nước - SCAR-L (Cấp 7)
    1101003070, -- Bí Ngô Ma Quái - SCAR-L (Cấp 7)
    1101003080, -- Chiến Dịch Vì Ngày Mai - SCAR-L (Cấp 7)
    1101003099, -- Drop Da Bass - SCAR-L (Cấp 7)
    1101003119, -- Tinh thể Hextech SCAR-L (Cấp 7)
    1101003188, -- Cái Ôm Của Chú Hề - SCAR-L (Cấp 7)
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
    1101003195, -- Thánh Nữ Huyền Ảo - SCAR-L (Cấp 7)
    1101003208, -- Vương Quốc Huyền Ảo - SCAR-L (Cấp 7)
    1101003219, -- Kính Pha Lê - SCAR-L (Cấp 7)
    1101003173, -- Ánh Sáng Hoàng Tộc - SCAR-L (Cấp 5)
    1101003212, -- Mèo Ăn Vặt - SCAR-L (Cấp 3)

    -- [ M762 ]
    1101008081, -- Vị Khách Nổi Loạn - M762 (Cấp 8)
    1101008104, -- Lõi Sao Huyền Ảo - M762 (Cấp 8)
    1101008146, -- Bạch Cốt U Minh - M762 (Cấp 8)
    1101008154, -- Khung Xương - M762 (Cấp 8)
    1101008051, -- Bản Nhạc Tình Yêu - M762 (Cấp 7)
    1101008061, -- Phát Bắn Chí Mạng - M762 (Cấp 7)
    1101008070, -- GACKT MOONSAGA - M762 (Cấp 7)
    1101008116, -- Biểu Tượng Bóng Đá Messi - M762 (Cấp 7)
    1101008126, -- Huyết Rồng - M762 (Cấp 7)
    1101008136, -- Tiên Linh Lưu Ly - M762 (Cấp 7)
    1101008163, -- Cổ Vật Hắc Ám - M762 (Cấp 7)
    1101008026, -- Pony Bé Nhỏ - M762 (Cấp 5)
    1101008036, -- Đóa Sen Phẫn Nộ - M762 (Cấp 5)

    -- [ AUG ]
    1101006062, -- Tinh Linh Băng Giá - AUG (Cấp 8)
    1101006085, -- Hoa Hồng Ma Mị - AUG (Cấp 8)
    1101006075, -- Hỏa Ca - AUG (Cấp 7)
    1101006033, -- Gánh Xiếc Rong - AUG (Cấp 5)
    1101006044, -- Evangelion Angel Thứ 4 - AUG (Cấp 5)
    1101006067, -- Ác Mộng Biển Sâu - AUG (Cấp 5)

    -- [ GROZA ]
    1101005038, -- Ryomen Sukuna - Groza (Cấp 7)
    1101005052, -- Lửa U Minh - Groza (Cấp 7)
    1101005098, -- Godzilla Bốc Lửa - Groza (Cấp 7)
    1101005019, -- Kỵ Binh Rừng Sâu - GROZA (Cấp 5)
    1101005025, -- Đêm Huyền Ảo - GROZA (Cấp 5)
    1101005043, -- Trận Chiến Sắc Màu - Groza (Cấp 5)
    1101005082, -- Lồng Đèn Bí Ngô - Groza (Cấp 5)
    1101005090, -- Di Tích Thượng Cổ - Groza (Cấp 5)
    1101005105, -- Singam Roar - Groza (Cấp 5)

    -- [ QBZ & Mk47 & G36C & Honey Badger & FAMAS & ASM Abakan & ACE32 ]
    1101007046, -- Công Chúa Hắc Ám - QBZ (Cấp 7)
    1101007062, -- Hoa Kiếm Chí Mạng - QBZ (Cấp 7)
    1101007071, -- Thiên Mệnh - QBZ (Cấp 7)
    1101007025, -- Ánh Dương - QBZ (Cấp 5)
    1101007036, -- Càn Quét - QBZ (Cấp 5)
    1101007079, -- Băng Quyền - QBZ (Cấp 5)
    1101009019, -- Thỏ Tinh Quái - Mk47 (Cấp 3)
    1101010029, -- Xung Nhịp Sân Cỏ - G36C (Cấp 5)
    1101012033, -- Cổ Mộc Chiến Khí - Honey Badger (Cấp 7)
-- Dump by Shadow TG SHD_CHT
    1101012009, -- Sắc Màu Huyền Ảo - Honey Badger (Cấp 5)
    1101012018, -- Thanh Âm Du Dương - Honey Badger (Cấp 5)
    1101012024, -- Honey Badger Mikey (Cấp 5)
    1101100012, -- Đế Vương Thần Vực - FAMAS (Cấp 8)
    1101100018, -- Ảo Ảnh Điện Tử - FAMAS (Cấp 5)
    1101101007, -- Uy Vũ Hắc Điểu - ASM Abakan (Cấp 7)
    1101102025, -- Thủy Quái - ACE32 (Cấp 8)
    1101102041, -- Tiên Tri Điềm Lành - ACE32 (Cấp 8)
    1101102049, -- Thì Thầm Cánh Bướm - ACE32 (Cấp 8)
    1101102007, -- Kamehameha - ACE32 (Cấp 7)
    1101102017, -- Ngọc Bích - ACE32 (Cấp 7)
    1101102032, -- Cáo Tinh Nghịch - ACE32 (Cấp 5)

    -- [ SMG (UZI, UMP45, Vector, Thompson, Bizon, MP5K, P90) ]
    1102001120, -- Băng Giá - UZI (Cấp 8)
    1102001130, -- Xiềng Xích Hỏa Ngục - UZI (Cấp 7)
    1102001024, -- Savagery - UZI (Cấp 6)
    1102001036, -- Vật Tổ Thần Bí - UZI (Cấp 5)
    1102001058, -- Khoảnh Khắc Bất Ngờ - UZI (Cấp 5)
    1102001069, -- UZI Quang Hóa (Cấp 5)
    1102001089, -- Ma Pháp - UZI (Cấp 5)
    1102001103, -- Cam Tươi Mát - UZI (Cấp 5)
    1102001102, -- Máy Ép Trái Cây - UZI (Cấp 5)
    1102002438, -- Song Tử Chiến - UMP45 (Cấp 8)
    1102002446, -- Song Tử Đỏ Thẫm - UMP45 (Cấp 8)
    1102002043, -- Hỏa long - UMP45 (Cấp 7)
    1102002061, -- Ảo Mộng Chết Chóc - UMP45 (Cấp 7)
    1102002136, -- Băng Giá - UMP45 (Cấp 7)
    1102002424, -- Thần Khí Anukhra - UMP45 (Cấp 7)
    1102002053, -- EMP - UMP45 (Cấp 5)
    1102002070, -- Đồ Tể Bạch Kim - UMP45 (Cấp 5)
    1102002090, -- Cuộc Chiến 8-Bit - UMP45 (Cấp 5)
    1102002112, -- Ngày Giáng Sinh - UMP45 (Cấp 5)
    1102002117, -- Ong Bắp Cày - UMP45 (Cấp 5)
    1102002129, -- Con Sóng Lễ Hội - UMP45 (Cấp 5)
    1102002143, -- PUBGM X NewJeans - UMP45 (Cấp 5)
    1102003080, -- Cánh Rồng - Vector (Cấp 7)
    1102003100, -- Tuyết Diệt Ảnh - Vector (Cấp 7)
    1102003020, -- Nanh Dơi Huyết Tộc - Vector (Cấp 5)
    1102003031, -- Hoa Hồng Đêm - Vector (Cấp 5)
    1102003039, -- Gấu Tinh Nghịch - Vector (Cấp 5)
    1102003052, -- Bá Tước Vàng - Vector (Cấp 5)
    1102003065, -- Lưỡi Liềm Vàng - Vector (Cấp 5)
    1102003072, -- Sát Thủ Tối Thượng - Vector (Cấp 5)
    1102003090, -- KMF Lancelot - Vector (Cấp 5)
    1102004018, -- Kẹo ngọt - Thompson (Cấp 5)
    1102004034, -- Máy Chạy Hơi Nước - Thompson (Cấp 5)
    1102004048, -- Tử Đằng - Thompson SMG (Cấp 3)
    1102005064, -- Quang Ảo Điện Tử - PP-19 Bizon (Cấp 7)
    1102005007, -- Tắc Kè - PP-19 Bizon (Cấp 5)
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    1102005020, -- Skullcrusher - PP-19 Bizon (Cấp 5)
    1102005041, -- Thần Binh Võ Thuật - PP-19 Bizon (Cấp 5)
    1102005052, -- DP Quantum Quake - Bizon (Cấp 5)
    1102005057, -- Lân Sư - PP-19 Bizon (Cấp 5)
    1102005072, -- Huyết Tế - PP-19 Bizon (Cấp 5)
    1102005078, -- SAKAMOTO SHOP - PP-19 (Cấp 5)
    1102007019, -- PUBGM X QWER - MP5K (Cấp 5)
    1102007022, -- Pixel Cổ Điển - MP5K (Cấp 3)
    1102105012, -- Miêu Nữ Công Nghệ - P90 (Cấp 7)
    1102105028, -- Thiên Mã - P90 (Cấp 7)
    1102105018, -- Móng Vuốt Hoàng Kim - P90 (Cấp 5)

    -- [ SNIPER & MARKSMAN RIFLE (Kar98, M24, AWM, SKS, SLR, Mk14, etc.) ]
    1103001202, -- Băng Yêu - Kar98K (Cấp 8)
    1103001060, -- Dấu nanh Phẫn nộ - Kar98K (Cấp 7)
    1103001079, -- Kukulkan Cuồng Nộ - Kar98K (Cấp 7)
    1103001101, -- Ánh Trăng - Kar98K (Cấp 7)
    1103001129, -- Gackt Moon - Kar98K (Cấp 7)
    1103001146, -- Cá Mập Titan - Kar98K (Cấp 7)
    1103001154, -- Mật Mã Chết Chóc - Kar98K (Cấp 7)
    1103001179, -- Điện Cực Tím - Kar98K (Cấp 7)
    1103001191, -- Hồng Hỏa Diệm - Kar98K (Cấp 7)
    1103001085, -- Đêm Nhạc Rock - Kar98K (Cấp 5)
    1103001160, -- Thợ Săn Tinh Vân - Kar98K (Cấp 5)
    1103001183, -- Nhịp Điệu Mèo Con - Kar98K (Cấp 3)
    1103002030, -- Quyền Trượng Pharaoh - M24 (Cấp 7)
    1103002059, -- Tuần Hoàn Sự Sống - M24 (Cấp 7)
    1103002087, -- Nhịp Điệu Hoàn Mỹ - M24 (Cấp 7)
    1103002106, -- Minh Nguyệt Cấm Vực - M24 (Cấp 7)
    1103002156, -- Bình Minh Bóng Tối - M24 (Cấp 7)
    1103002049, -- Hồ Điệp Phu Nhân - M24 (Cấp 5)
    1103002047, -- Giai Điệu Chí Mạng - M24 (Cấp 5)
    1103002094, -- Công Nghệ Cao - M24 (Cấp 5)
    1103003022, -- Neon - AWM (Cấp 7)
    1103003030, -- Chỉ Huy Chiến Trường - AWM (Cấp 7)
    1103003042, -- Godzilla - AWM (Cấp 7)
    1103003051, -- Đại Long Cầu Vồng - AWM (Cấp 7)
    1103003062, -- Hỏa Phượng Hoàng - AWM (Cấp 7)
    1103003079, -- Huyết Hải Thiên Long - AWM (Cấp 7)
    1103003087, -- Thanh Hoa Xà - AWM (Cấp 7)
    1103003099, -- Hắc Khí - AWM (Cấp 7)
    1103003092, -- Hồng Hoang - AWM (Cấp 5)
    1103004037, -- Quý Bà Đỏ - SKS (Cấp 7)
    1103004046, -- Rừng Thép - SKS (Cấp 5)
    1103004058, -- Năng Lượng Băng Tuyết - SKS (Cấp 5)
    1103004080, -- Khiết Hoa Nở Rộ - SKS (Cấp 5)
    1103004087, -- Giai Điệu Tử Thần - SKS (Cấp 5)
    1103005024, -- Quạ Đen - VSS (Cấp 5)
    1103005048, -- Trinh Sát Tuyết Trắng - VSS (Cấp 3)
    1103009022, -- Mùa Hoa Đào - SLR (Cấp 5)
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
    1103009037, -- Ngọn Lửa Ma Thuật - SLR (Cấp 5)
    1103009051, -- Ma Mộng - SLR (Cấp 5)
    1103009042, -- Thanh Âm Hải Huyền - SLR (Cấp 3)
    1103006030, -- Sông Băng - Mini14 (Cấp 7)
    1103006046, -- Nét Đẹp Thuần Khiết - Mini14 (Cấp 5)
    1103006058, -- Mèo Chiêu Tài - Mini14 (Cấp 5)
    1103006063, -- Tay Đua Gan Dạ - Mini14 (Cấp 5)
    1103006075, -- Nhịp Chiến Nhanh - Mini14 (Cấp 5)
    1103007028, -- Vương Quốc Rồng - Mk14 (Cấp 8)
    1103007020, -- Sức Mạnh Ngân Hà - Mk14 (Cấp 5)
    1103007038, -- Rồng Sữa Mềm Mại - Mk14 (Cấp 5)
    1103007043, -- Hộp Quà May Mắn - Mk14 (Cấp 5)
    1103012010, -- Khủng Long Ephialtes - AMR (Cấp 8)
    1103012019, -- Hỏa Thần - AMR (Cấp 7)
    1103012031, -- Vô Âm Ly Biệt - AMR (Cấp 7)
    1103012039, -- Đại Chiến Huyễn Sắc - AMR (Cấp 7)
    1103012024, -- Tinh Thể Onyx - AMR (Cấp 5)
    1103100007, -- Thú Săn Mồi - Mk12 (Cấp 5)
    1103102007, -- Chiến Hạm Vũ Trụ - DSR (Cấp 7)
    1103103007, -- Vinh Quang Chiến Binh - M1 Garand (Cấp 7)

    -- [ SHOTGUN & MACHINE GUN (S12K, DBS, M249, DP-28, MG3...) ]
    1104001035, -- Độc Hồn - S686 (Cấp 5)
    1104002022, -- Chạng Vạng - S1897 (Cấp 5)
    1104002049, -- Xung Kích Sắc Màu - S1897 (Cấp 3)
    1104003026, -- S12K GACKT (Cấp 7)
    1104003037, -- Kích Hoạt Nguyên Tử - S12K (Cấp 5)
    1104003046, -- Trái Tim Cyber - S12K (Cấp 5)
    1104004035, -- Chiến Giáp Quái Thú - DBS (Cấp 5)
    1104004041, -- Sandsinger - DBS (Cấp 5)
    1104004051, -- Okarun - DBS (Cấp 5)
    1104004024, -- Báo Sắc Màu - DBS (Cấp 3)
    1104102004, -- Tàn Tích Hoàng Kim - NS2000 (Cấp 3)
    1105001034, -- Pháo Giáng Sinh - M249 (Cấp 7)
    1105001048, -- Nữ Đế Ánh Sáng - M249 (Cấp 7)
    1105001069, -- Vương Quyền Hắc Ám - M249 (Cấp 7)
    1105001020, -- Nữ Hoàng Băng Giá M249 V (Cấp 5)
    1105001054, -- Stargaze Fury - M249 (Cấp 5)
    1105001062, -- Graffiti Đường Phố - M249 (Cấp 5)
    1105001075, -- Cá Mập Thép - M249 (Cấp 4)
    1105002091, -- Huyết Họa - DP28 (Cấp 8)
    1105002018, -- Sát Thủ Bí Ẩn - DP-28 (Cấp 5)
    1105002035, -- Ngọc Long - DP-28 (Cấp 5)
    1105002058, -- Chiến Binh Hàng Hải - DP28 (Cấp 5)
    1105002063, -- Rồng Thần Shenron - DP-28 (Cấp 5)
    1105002071, -- Chiến Sĩ Thần Giáp - DP-28 (Cấp 5)
    1105002076, -- Mèo Số Hóa - DP-28 (Cấp 5)
    1105002083, -- DP-28 Frieren's Staff (Cấp 5)
    1105002096, -- Hồ Tộc - DP-28 (Cấp 3)
    1105010019, -- Chiến Thần Bầu Trời - MG3 (Cấp 7)
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
    1105010008, -- Thiên Khung - MG3 (Cấp 5)
    1105010026, -- Mina Ashiro - MG3 (Cấp 5)

    -- [ CẬN CHIẾN & VŨ KHÍ KHÁC (Skorpion, Nỏ, Chảo, Dao...) ]
    1106008013, -- Mật Mã Vàng - Skorpion (Cấp 5)
    1106008022, -- Bí Ẩn Tinh Tú - Skorpion (Cấp 3)
    1106011008, -- Rồng Rắn Lên Mây - MP7 Kép (Cấp 5)
    1106011003, -- Thợ Săn Kẹo - MP7 (Cấp 3)
    1107001018, -- Chúa Hề Thịnh Nộ - Nỏ (Cấp 3)
    1107098003, -- Rung Chấn Công Nghệ - MGL (Cấp 3)
    1108001057, -- Săn Rồng - Dao (Cấp 3)
    1108001064, -- Đoản Kiếm Yor SPY×FAMILY (Cấp 3)
    1108001069, -- Ki Sword (Cấp 3)
    1108001081, -- Rìu Godzilla Bốc Lửa (Cấp 3)
    1108001085, -- Kiếm Trung Đoàn Trinh Sát Cấp 3
    1108001098, -- Thương Đảo Ngược Thiên Đường - Dao (Cấp 3)
    1108001104, -- Xích Tay - Dao (Cấp 3)
    1108002059, -- Đinh Ba Thủy Triều Thịnh Nộ (Cấp 5)
    1108004125, -- Hũ Mật Ong - Chảo (Cấp 5)
    1108004160, -- Cá Sấu - Chảo (Cấp 5)
    1108004145, -- Đêm Nhạc Rock - Chảo (Cấp 5)
    1108004283, -- Vinh Quang - Chảo (Cấp 6)
    1108004337, -- Chảo Điện Nguyên Tử (Cấp 6)
    1108004356, -- Gà Rán - Chảo (Cấp 3)
    1108004365, -- Yokai Huyền Bí - Chảo (Cấp 3)
    1108004377, -- Chảo Cánh Cụt Vui Vẻ (Cấp 5)
    1108004416, -- Quạt Vũ Điệu Nóng Bỏng - Chảo (Cấp 3)
    1108005050, -- Rồng Băng Giá - Dao Găm (Cấp 3)

    -- ==============================================================================
    -- 2. FULL SIÊU XE (VIP VEHICLES)
    -- ==============================================================================
    -- [ McLaren ]
    1961007, -- McLaren 570S (Đen)
    1961010, -- McLaren 570S (Trắng)
    1961012, -- McLaren 570S (Hồng)
    1961013, -- McLaren 570S (Vàng Trắng)
    1961014, -- McLaren 570S (Vàng Đen)
    1961015, -- McLaren 570S (Ánh Kim)
    1961147, -- McLaren P1 (Trời Sao)
    1961148, -- McLaren P1 (Hồng Rực Rỡ)
    1961149, -- McLaren P1 (Vàng Núi Lửa)
    1907054, -- Xe Đua Đội McLaren F1 (Điện Tử)
    1907058, -- Xe Đua Đội McLaren F1
    1907059, -- Xe Đua Đội McLaren F1 (Chiến Thắng)

    -- [ Koenigsegg ]
    1961016, -- Koenigsegg Jesko (Xám Bạc)
    1961017, -- Koenigsegg Jesko (Cầu Vồng)
    1961018, -- Koenigsegg Jesko (Bình Minh)
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    1961029, -- Koenigsegg One:1 Gilt
    1961030, -- Koenigsegg One:1 Cyber VIPGROUP 
    1961031, -- Koenigsegg One:1 Jade
    1961032, -- Koenigsegg One:1 Phoenix
    1903074, -- Koenigsegg Gemera (Xám Bạc)
    1903075, -- Koenigsegg Gemera (Cầu Vồng)
    1903076, -- Koenigsegg Gemera (Bình Minh)

    -- [ Lamborghini ]
    1961020, -- Lamborghini Aventador SVJ Verde Alceo
    1961021, -- Lamborghini Centenario Galassia
    1961024, -- Lamborghini Aventador SVJ Blue
    1961025, -- Lamborghini Centenario Carbon Fiber
    1961144, -- Lamborghini Invencible Rosso Efesto
    1961145, -- Lamborghini Invencible VIPGROUP  Drift
    1903079, -- Lamborghini Estoque Oro
    1903080, -- Lamborghini Estoque Metal Grey
    1908066, -- Lamborghini Urus Pink
    1908067, -- Lamborghini Urus Giallo Inti

    -- [ Bugatti ]
    1961041, -- Bugatti Veyron 16.4 (Sắc Màu)
    1961042, -- Bugatti Veyron 16.4 (Vàng)
    1961043, -- Bugatti Veyron 16.4
    1961044, -- Bugatti La Voiture Noire
    1961045, -- Bugatti La Voiture Noire (Hợp Kim)
    1961046, -- Bugatti La Voiture Noire (Chiến Binh)
    1961047, -- Bugatti La Voiture Noire (Tinh Vân)
    1961151, -- Bugatti Bolide (Lưỡi Gương)
    1961152, -- Bugatti Bolide (Bỉ Ngạn)
    1961153, -- Bugatti Bolide (Ảo Ảnh Hồ Băng)

    -- [ Aston Martin ]
    1961048, -- Aston Martin Valkyrie (Luminous Diamond)
    1961049, -- Aston Martin Valkyrie (Racing Green)
    1915005, -- Aston Martin DBS Volante (Deep Cosmos)
    1915006, -- Aston Martin DBS Volante (Celestial Pink)
    1915007, -- Aston Martin DBS Volante (Black-Bronze Satin)
    1908084, -- Aston Martin DBX707 (Neon Purple)
    1908085, -- Aston Martin DBX707 (Quasar Blue)

    -- [ Pagani ]
    1961051, -- Pagani Zonda R (Tricolore Carbon)
    1961052, -- Pagani Zonda R (Bianco Benny)
    1961053, -- Pagani Zonda R (Melodic Midnight)
    1961054, -- Pagani Imola (Grigio Montecarlo)
    1961055, -- Pagani Imola (Crystal Clear Carbon)
    1961056, -- Pagani Imola (VIPGROUP  Dream)
    1961057, -- Pagani Imola (Arctic Aegis)

-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
    -- [ Bentley ]
    1961137, -- Bentley Batur (Kim Cương Lấp Lánh)
    1961138, -- Bentley Batur (Tận Cùng Thời Gian)
    1961139, -- Bentley Betayga Azure (Vương Quốc Huyền Ảo)
    1903200, -- Bentley Flying Spur Mulliner (Tinh Vân Xanh)
    1903201, -- Bentley Flying Spur Mulliner (Dòng Chảy Vịnh Hẹp)
    1908094, -- Bentley Betayga Azure (Mưa Hoa)
    1908095, -- Bentley Betayga Azure (Đêm Yên Tĩnh)
    1915008, -- Bentley Continental GTC Mulliner (Mộng Cảnh Lung Linh)
    1915009, -- Bentley Continental GTC Mulliner (Quý Tộc Áo Tím)

    -- [ Maserati ]
    1961038, -- Maserati MC20 Bianco Audace
    1961039, -- Maserati MC20 Rosso Vincente
    1961040, -- Maserati MC20 Sogni
    1908075, -- Maserati Levante Blu Emozione
    1908076, -- Maserati Luce Arancione
    1908077, -- Maserati Levante Neon Urbano
    1908078, -- Maserati Levante Firmamento

    -- [ Dodge / SRT ]
    1961036, -- Dodge Challenger SRT Hellcat - Blaze
    1961037, -- Dodge Challenger SRT Hellcat - Lime
    1961050, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1961136, -- Dodge Challenger SRT Hellcat - Blaze
    1961150, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1903088, -- Dodge Charger SRT Hellcat - Fuchsia
    1903089, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903090, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1903189, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903190, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1908086, -- Dodge Hornet - Scarlet Sting
    1908088, -- Dodge Hornet GLH Concept - Redline
    1908089, -- Dodge Hornet - Sunburst
    1908188, -- Dodge Hornet GLH Concept - Redline
    1908189, -- Dodge Hornet - Sunburst

    -- [ Porsche ]
    1961062, -- Porsche 918 Spyder (Dòng Nước)
    1961063, -- Porsche 918 Spyder (964 Bạc Ánh Kim)
    1961064, -- Porsche 918 Spyder (Hồng)
    1903218, -- Porsche Panamera Turbo S (Lam Ngọc)
    1903219, -- Porsche Panamera Turbo S (Xanh Viper)
    1908108, -- Porsche Cayenne Turbo GT (Đường Đua Rực Lửa)
    1908109, -- Porsche Cayenne Turbo GT (Cam Dung Nham)
    1915021, -- Porsche 911 Carrera 4 GTS Cabriolet (Ngàn Sao)
    1915022, -- Porsche 911 Carrera 4 GTS Cabriolet (Đỏ Ruby)

    -- [ Shelby / Ford ]
    1961058, -- Shelby 427 Cobra (Xanh & Trắng)
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
    1961059, -- Shelby 427 Cobra (Graffiti Phục Cổ)
    1903210, -- Shelby GT500 (Đen & Đỏ)
    1903211, -- Shelby GT500 (Người Ngoài Hành Tinh Cyber)
    1961068, -- Ford Mustang GTD (Huyền Thoại Xanh Tươi)
    1961069, -- Ford Mustang GTD (Tinh Thần Nước Mỹ)

    -- [ Lotus ]
    1961060, -- Lotus Emira (Rừng Sâu Thẫm)
    1961061, -- Lotus Emira (Lướt Sắc Xanh)

    -- [ Apollo ]
    1961065, -- Apollo EVO (Vàng Rực Rỡ)
    1961066, -- Apollo EVO (Hoàng Hôn)
    1961067, -- Apollo EVO (Băng Giá)
    1903220, -- Apollo Intensa Emozione (Hỏa Ngục Nóng Chảy)
    1903221, -- Apollo Intensa Emozione (Bóng Ma Tím)
    1903222, -- Apollo Intensa Emozione (Quyết Đấu)
    1903223, -- Apollo Intensa Emozione (Bão Tố)

    -- [ SSC Tuatara ]
    1961140, -- Ảo Ảnh Hoa Hồng SSC Tuatara
    1961141, -- Hạc Trời SSC Tuatara
    1961142, -- Đao Bình Minh SSC Tuatara Striker
    1961143, -- Màn Đêm Xanh SSC Tuatara Striker

    -- [ Tesla ]
    1903071, -- Tesla Roadster (Kim Cương)
    1903072, -- Tesla Roadster (Pha Lê Tím)
    1903073, -- Tesla Roadster (Xanh Biển Cả)

    -- [ Ducati / Motor VIP ]
    1901073, -- DUCATI Panigale V4S
    1901074, -- Ducati Panigale V4S Black Phantom
    1901075, -- Ducati Panigale V4S Crimson Storm
    1901076, -- Ducati Panigale V4S Swift Mirage

    -- ==============================================================================
    -- 3. FULL BAY DÙ (DÙ RƠI, TÀU LƯỢN, VÁN TRƯỢT BAY)
    -- ==============================================================================
    -- [ DÙ (Parachutes) ]
    1401000, -- New Years Blessing Parachute
    1401001, -- Happy New Year Parachute
    1401002, -- Dù Xương Đỏ
    1401003, -- Dù tiểu quỷ tinh nghịch
    1401005, -- Dù nhện biến hình
    1401006, -- Dù Mùa 5
    1401007, -- Dù sinh nhật
    1401008, -- Dù Sếu Vàng
    1401009, -- Dù Quỷ Đỏ
    1401010, -- Dù hoa bách thảo
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    1401011, -- Dù anh đào
    1401012, -- Dù Campus Tournament
    1401013, -- Dù Joker
    1401014, -- Dù chú hề
    1401015, -- Carabao Parachute
    1401016, -- Orange Life Parachute
    1401017, -- Dù ưng vàng
    1401018, -- Dù Quán quân Mùa 8
    1401019, -- Dù Đội trưởng Ryan
    1401020, -- Dù kẻ lang thang
    1401021, -- Dù cung trăng
    1401022, -- OPPO F11 PRO SURVIVOURS PARACHUTE
    1401023, -- Dù lãnh chúa Sekigahara (Vuông)
    1401024, -- Dù Đồng Minh Loot Thính
    1401025, -- Dù Đêm Mê Hoặc (Vuông)
    1401026, -- Dù cát tường
    1401027, -- Dù PMCO
    1401028, -- Dù Quán quân Mùa 7
    1401029, -- Dù sinh nhật rực rỡ
    1401031, -- Dù Quán quân Mùa 6
    1401032, -- Dù Dao Găm Đỏ
    1401033, -- Dù WALKER
    1401034, -- Dù Phù Thủy Băng Giá
    1401035, -- Dù người thách đấu
    1401036, -- Dù BAPE X PUBGM CAMO
    1401037, -- Dù Godzilla (Trắng)
    1401038, -- Dù Godzilla (Vàng)
    1401039, -- Dù Godzilla (Xanh)
    1401040, -- Dù Monarch
    1401041, -- Dù Cà Ri
    1401043, -- Dù Người Gác Đêm
    1401044, -- Dù hoa hồng đen
    1401045, -- Dù Mèo May Mắn
    1401046, -- Dù Đêm u ám
    1401047, -- Dù Cá Voi Sát Thủ
    1401048, -- Dù thủy quái Kraken
    1401050, -- Dù giai điệu âm nhạc
    1401051, -- Dù OPPO Reno
    1401052, -- Dù OPPO VOOC
    1401053, -- Dù Đêm Mê Hoặc
    1401054, -- Dù Chú Heo Tinh Nghịch
    1401055, -- Dù Red (Dài)
    1401056, -- PMJC Parachute
    1401057, -- PMSC Parachute
    1401059, -- Dù Quán quân Draconian
    1401060, -- Dù lãnh chúa Sekigahara
    1401061, -- Dù Tiểu Quỷ
    1401062, -- Dù Quán quân Mùa 9
    1401063, -- Dù Quán quân Mùa 10
    1401064, -- Dù Mèo Đen
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
    1401065, -- Dù Gà trống
    1401066, -- Dù Mọt Sách Băng Giá
    1401067, -- Dù Người Giảm Đau #11
    1401068, -- Super Power Parachute
    1401071, -- Dù Luân Hồi Vô Tận
    1401072, -- Dù Chúa Tể Muôn Loài
    1401074, -- Dù Bí Ngô Kinh Dị
    1401085, -- Dù Gà Thơm Ngon
    1401086, -- Dù Quán quân Mùa 11
    1401087, -- Dù Hoa Sen Máu
    1401088, -- Dù Hành Tinh Trôi Dạt
    1401089, -- Dù Quán Quân Mùa 12
    1401090, -- Dù Ninja Sát Thủ
    1401091, -- Dù Neko Sakura
    1401092, -- Dù Người Tiên Phong
    1401094, -- Dù Fantasy Girl
    1401095, -- Dù Tranh Vẽ Chiến Trường
    1401096, -- Dù Người Phán Quyết
    1401097, -- Dù Africa Pride
    1401098, -- Dù Africa Unite
    1401100, -- Dù Cậu Vàng
    1401102, -- Dù đặc vụ PMSC World Cup
    1401103, -- Dù Quân Đoàn Thất Lạc
    1401104, -- Dù Giải Đấu PMCO
    1401106, -- Dù Trung Úy Vũ Trụ
    1401107, -- Dù Đầy Tớ Huyết Nha
    1401108, -- Dù Street Dancer 3
    1401109, -- Dù Unique KingCard
    1401111, -- Dù Bánh Ú
    1401112, -- Dù Gào Thét
    1401113, -- Dù Thủ Vệ Tự Do
    1401115, -- Dù Kẹo Ngọt
    1401117, -- Dù Cao Bồi Viễn Tây
    1401119, -- Dù Giáp Samurai
    1401122, -- Incredible Parachute
    1401124, -- Dù Warrior
    1401125, -- Dù Quý Cô Gothic
    1401127, -- Dù Thần Thoại Ả Rập
    1401128, -- Dù Nhà Vô Địch Arena
    1401129, -- Dù Quán Quân Mùa 13
    1401130, -- Dù Gorilla
    1401131, -- Dù PMGC
    1401133, -- Dù Mùa 15
    1401134, -- Dù Tulip
    1401135, -- Dù Ác Ma Cuồng Nộ
    1401137, -- Dù Mùa 14
    1401138, -- Dù Pro League (Vàng)
    1401139, -- Dù Pro League (Bạc)
    1401140, -- Dù Lạc Đà Bảnh Bao
    1401141, -- Dù Gà Rán
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
    1401142, -- Dù CLB Hoàng Gia
    1401145, -- Dù Bảy Sắc
    1401146, -- Dù Mountain Dew
    1401147, -- Dù Tư Tế Tối Cao
    1401148, -- Dù Idol
    1401149, -- Dù Dang Rộng Đôi Cánh
    1401150, -- Dù Chiến Binh Thép
    1401151, -- Dù Quán Quân Mùa 16
    1401152, -- Dù Liềm Tử Thần
    1401153, -- Dù emoji Thỏa Mãn
    1401154, -- Dù emoji
    1401155, -- Dù emoji Vui Nhộn
    1401156, -- Dù Qualcomm
    1401157, -- Dù Điểm Sơ Tán
    1401159, -- Dù Lãnh Chúa Độc Tài
    1401160, -- Dù Kẹp Hạt Dẻ Vui Vẻ
    1401161, -- Dù Long Vương
    1401163, -- Dù Giáp Chiến Thần
    1401164, -- Dù Giai Điệu Yêu Thương
    1401165, -- Dù Quán Quân Mùa 17
    1401167, -- Dù Ánh Trăng Huyền Bí
    1401168, -- Dù Tiệc Disco
    1401169, -- Dù Quán Quân Mùa 18
    1401170, -- Dù Tuyết Anh Đào
    1401171, -- Dù Tổ Ong
    1401174, -- Dù Quán Quân Mùa 19
    1401177, -- Dù Quán Quân C1S1
    1401178, -- Dù Băng Cát Sét
    1401179, -- Dù El Diablo
    1401181, -- Chúa Tể Băng Giá - Dù
    1401182, -- Dù Kẻ Săn Mồi Biển Xanh
    1401183, -- Dù Mộng Điệp
    1401184, -- Dù Bọ Cánh Cứng
    1401186, -- Dù Rùa và Thỏ
    1401187, -- Dù Nhịp Bước Mạnh Mẽ
    1401188, -- Dù PMPL Mùa Xuân 2021
    1401189, -- Dù GodzillaVsKong
    1401190, -- Dù Hành Trình Kỳ Diệu
    1401191, -- Dù Dấu Ấn Vũ Trụ
    1401192, -- Dù Đầu Bếp Gà
    1401193, -- Dù Nghệ Thuật Sắc Màu
    1401194, -- Dù Aerial Punk Rich Brian
    1401195, -- Dù OPPO
    1401196, -- Dù BUG
    1401197, -- Dù Chúa Tể Bánh Răng
    1401198, -- Dù Xiaomi
    1401200, -- Dù Đôi Mắt Biển Sâu
    1401201, -- Dù OnePlus
    1401204, -- Dù foodpanda
    1401205, -- Dù PMPL Mùa Thu 2021
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
    1401208, -- Dù Thành Phố Trên Không
    1401209, -- Dù Bóng Ma Tương Lai
    1401210, -- Dù Mật Thám Cơ Khí
    1401212, -- Dù Thành Phố Sắc Màu
    1401213, -- Dù Súng Hoa Hồng
    1401215, -- Dù Băng Giá
    1401216, -- Dù Bản Đồ Kho Báu
    1401217, -- Dù Cơn Sốt Giáng Sinh
    1401218, -- Dù Họa Tiết Vàng
    1401219, -- Dù Vương Quốc Vàng
    1401220, -- Dù Hoàng Hôn Rực Rỡ
    1401221, -- Dù Bồ Câu Trắng
    1401222, -- Dù Vòng Xoay Thời Gian
    1401223, -- Dù Zong
    1401224, -- Dù Quán Quân C1S2
    1401225, -- Dù Quán Quân C1S3
    1401227, -- Dù Đại Hạ Giá
    1401228, -- Dù Lãng Khách Thời Thượng
    1401231, -- Dù PMGC 2021
    1401232, -- Dù Liverpool FC
    1401233, -- Dù Đột Phá
    1401234, -- Dù Voi Sắc Màu
    1401235, -- Dù Hợp Tác Egor Kreed
    1401236, -- Gackt Moon Parachute
    1401237, -- Dù Dune
    1401238, -- Dù Guruh Gundala
    1401239, -- Dù C2S4
    1401240, -- Dù Baby Shark
    1401241, -- Dù JAPAN LEAGUE S2
    1401242, -- Dù Đầu Bếp Quái Thú
    1401243, -- Dù Bá Chủ Đại Dương
    1401244, -- Dù C2S5
    1401245, -- Dù Nữ Hoàng Điện Tử
    1401246, -- Dù Nhâm Dần
    1401247, -- Dù Sắc Xuân
    1401248, -- Dù Jujutsu Kaisen
    1401249, -- Dù Shiba Inu
    1401250, -- Dù Motorola
    1401252, -- Dù Trận Chiến Trendy
    1401254, -- Dù DJ Cá Tính
    1401255, -- Dù Chị Chị Em Em
    1401256, -- Dù Graffiti Neon
    1401257, -- Dù C2S6
    1401258, -- Dù Người Nhện: Không Còn Nhà
    1401259, -- Dù Sát Thủ Thời Không
    1401260, -- Dù Vùng Đất Hoang
    1401261, -- Dù Sắc Màu
    1401262, -- Dù Lễ Hội Sắc Màu
    1401263, -- Dù Rạp Xiếc Thần Kỳ
    1401264, -- Dù Thiếu Nữ Tóc Đỏ
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
    1401265, -- Dù Bộ Đôi Hoàn Hảo
    1401266, -- Dù Thiếu Nữ Song Sinh
    1401267, -- Dù Cánh Cổng Kỳ Dị
    1401268, -- Dù Thiếu Nữ Anime
    1401269, -- Dù Gà Chiến Đấu
    1401270, -- Dù Nến Xanh
    1401271, -- Dù Hồn Ma Nghịch Ngợm
    1401272, -- Dù Thiếu Nữ Cầu Nguyện
    1401273, -- Dù Ma Nữ Đáng Yêu
    1401274, -- Dù Evangelion NERV
    1401275, -- Dù Chị Em Song Sinh
    1401276, -- Dù PMPL Mùa Xuân 2022
    1401277, -- Dù Gấu Teddy GB
    1401278, -- Dù Sư Tử Thời Trang
    1401280, -- Dù Kỷ Niệm Tuổi Thơ
    1401281, -- Dù C3S7
    1401282, -- Dù Mèo Khổng Lồ
    1401283, -- Dù Butterfinger
    1401284, -- Siêu Dù Nhảy
    1401285, -- Dù Đồng Minh Mùa Hè
    1401286, -- Dù Sóc Chuột
    1401287, -- Dù Hỏa Diệm Ma Giáp
    1401289, -- Dù Heartrocker
    1401290, -- Dù Sư Tử Lưỡng Hà
    1401291, -- Dù realme
    1401292, -- Dù Lil Burger
    1401294, -- Dù Dòng Sông Mộng Mơ
    1401295, -- Dù C3S8
    1401296, -- Dù Đêm Của Phép Màu
    1401298, -- Dù Vinh Quang
    1401299, -- Dù Bản Đồ Sao
    1401300, -- Dù Chúa Tể Gai Độc
    1401301, -- Dù Bóng Ma Và Nàng
    1401302, -- Dù Gai Bé Bỏng
    1401303, -- Dù Uqabi
    1401308, -- Dù Phù Thủy Băng Giá
    1401309, -- Dù Tốc Độ Cực Hạn
    1401310, -- Dù PMWI 2022
    1401311, -- BGMI Esports Parachute
    1401312, -- PMJL SEASON3 Parachute
    1401313, -- PMPS 2022 Parachute
    1401314, -- Dù Chiến Binh Ngưu
    1401315, -- Dù Quyền Lực Tối Thượng
    1401316, -- Dù Đội Bóng Ả Rập
    1401317, -- Dù Ngàn Sao Rực Rỡ
    1401318, -- Dù Pháp Sư Thiên Văn
    1401319, -- Dù C3S9
    1401320, -- Dù BoBoiBoy
    1401323, -- Dù Đường Đua Hoang Dã
    1401324, -- Dù Tuần Lộc Trắng
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
    1401325, -- Dù Rìu Hoàng Kim
    1401326, -- Dù Vàng Huyền Bí
    1401330, -- Dù Du Hành Tinh Vân
    1401332, -- Dù Mèo Tuyết
    1401334, -- Dù KFC
    1401335, -- Dù Thủy Sư Cuồng Nộ
    1401336, -- Dù Sọ Nham Thạch
    1401337, -- Dù Bá Chủ Bầu Trời
    1401338, -- Dù Grubhub
    1401339, -- Dù AFA
    1401340, -- Dù Huyền Thoại Siêu Sao Messi
    1401343, -- Dù PMGC 2022
    1401345, -- Dù Bản Đồ Kho Báu
    1401346, -- Dù Nobru
    1401347, -- Dù Sony
    1401349, -- Dù Đột Kích Trên Không
    1401351, -- Dù Nữ Hiệp
    1401353, -- Dù Chú Hề Quỷ Quyệt
    1401355, -- Dù Lý Tiểu Long
    1401356, -- Dù Cặp Đôi Diễn Võ
    1401357, -- Dù Donkey King
    1401360, -- Dù Pro League
    1401361, -- Dù Kế Hoạch Đỏ Thẫm
    1401362, -- Dù C4S11
    1401363, -- Dù Bản Đồ Vũ Trụ
    1401364, -- Dù BESHADOW
    1401365, -- Dù Nguồn Sáng Vinh Quang
    1401366, -- Dù Ký Ức Xưa
    1401367, -- Dù Bugatti
    1401368, -- Dù Hóa Thạch Khủng Long
    1401369, -- Dù Trốn Thoát T-Rex
    1401370, -- Dù Dragon Ball Super
    1401371, -- Dù C4S12
    1401372, -- Dù Huyết Rồng
    1401373, -- UNIVERSTAR BT21 Parachute
    1401374, -- Dù HUAWEI AppGallery
    1401375, -- Dù PMWI 2023
    1401376, -- Dù C5S13
    1401377, -- Dù Thỏ Disco
    1401378, -- Dù Aston Martin
    1401379, -- Dù Mùa Hè Trên Bãi Biển
    1401380, -- Dù C5S14
    1401381, -- Dù C5S15
    1401382, -- Dù PMGC 2023
    1401383, -- Dù KFC
    1401385, -- Dù Yeti Khổng Lồ
    1401386, -- Dù Pagani
    1401387, -- Dù Báo Sắc Màu
    1401388, -- Dù Bé Sóc Đáng Yêu
    1401389, -- Dù Kỳ Giông Hồng
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
    1401390, -- RS Swagster Parachute
    1401391, -- Dù Gấu Trúc Ngọt Ngào
    1401392, -- Dù Chiến Binh Hoa Hồng
    1401393, -- Dù Cuộc Chiến Chính Nghĩa
    1401394, -- Dù LINE FRIENDS
    1401395, -- Dù Hồ Ly Thần Bí
    1401396, -- Dù Zanmang Loopy
    1401397, -- Hardik Sky Parachute
    1401398, -- Dù C6S16
    1401399, -- Dù Bóng Ma Quyến Rũ
    1401400, -- Dù Bảo Hộ Hoàng Gia
    1401401, -- Dù Bentley
    1401402, -- SPY×FAMILY Dù
    1401403, -- Dù Nhật Thực
    1401404, -- Dù Chiến Sĩ Thần Giáp
    1401405, -- Dù C6S17
    1401406, -- Dù Giai Điệu Mèo Con
    1401407, -- Dù Thành Phố Hỗn Loạn
    1401408, -- Dù Đôi Cánh Cận Vệ
    1401409, -- Dù Thiết Mã
    1401410, -- Dù Bay Lướt Vũ Trụ
    1401411, -- Dù C6 S18
    1401412, -- Dù Nữ Đế Hắc Ám
    1401413, -- Dù Hợp Tác Lamborghini
    1401416, -- Dù Tượng Đá Cổ Xưa
    1401417, -- Dù Đại Dương Xanh
    1401418, -- KAKAO FRIENDS Parachute
    1401419, -- Dù Infinix GT
    1401420, -- Dù Esports World Cup 2024
    1401421, -- Dù C7S19
    1401422, -- Dù Thỏ Tinh Quái
    1401423, -- Dù Hợp Tác VW
    1401424, -- Dù Miêu Linh Sắc Màu
    1401425, -- Dù Hắc Long Ma Nhãn
    1401426, -- Dù Âm Dương
    1401427, -- NieR:Automata Parachute
    1401428, -- Dù Đam Mê Esports
    1401429, -- Dù C7S20
    1401430, -- Dù Venom: Kèo Cuối
    1401431, -- Dù Bộ Tộc Ngân Hà
    1401432, -- Dù Tuần Lộc Hoàng Gia
    1401433, -- Dù McLaren
    1401434, -- Dù PMGC 2024
    1401435, -- Dù lượn Sói Tuyết
    1401436, -- Dù lượn Bóng Nước
    1401437, -- Dù lượn C7S21
    1401438, -- Dù Cá Koi Xuân Sắc
    1401439, -- Dù Đại Bàng
    1401440, -- Dù Hoa Hồng Bóng Đêm
    1401441, -- Opanchu Parachute
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
    1401442, -- Neon Drop BE 6 Parachute
    1401443, -- Dù C8S22
    1401444, -- Dù Lượn Hắc Cốt
    1401445, -- Dù Cực Quang Tinh Tú
    1401446, -- Godzilla vs. Dù Destoroyah
    1401447, -- Dù Thỏ Bồng Bềnh
    1401448, -- Parachute(Frieren&Fern)
    1401449, -- Dù C8S23
    1401450, -- Dù Lượn Mã Số Hóa 
    1401451, -- Dù Lượn Khuếch Đại Sắc Màu
    1401452, -- Dù Hợp Tác Shelby
    1401453, -- Dù Ráng Chiều Rực Cháy
    1401454, -- Dù Attack on Titan
    1401455, -- Dù Cơ Khí 
    1401456, -- Mountain Dew Neon Shard Parachute
    1401457, -- Dù C8S24
    1401458, -- Dù Vũ Trụ
    1401459, -- Dù Transformers
    1401460, -- Dù Thần Mệnh
    1401461, -- Dù Cún Yêu
    1401462, -- Bbangbbang's diary Parachute
    1401463, -- Realme Parachute
    1401464, -- Dù Infinix GT
    1401465, -- Dù C9S25
    1401466, -- Dù Ác Quỷ
    1401467, -- Dù Kaiju No. 8
    1401468, -- Dù TEAM SONIC
    1401469, -- Dù Hồ Điệp Lấp Lánh
    1401470, -- Dù Lotus
    1401471, -- Dù Bông Xù
    1401472, -- Dù Gen Hoàn Hảo
    1401473, -- Tokyo Revengers Parachute
    1401474, -- Sky Striker Parachute
    1401475, -- Dù C9S26
    1401476, -- Dù Lượn Gấu Ngọt Ngào
    1401477, -- Dù Balenciaga
    1401478, -- Dù Lượn Tuyết Hàn
    1401479, -- Dù Porsche
    1401480, -- Dù Hắc Linh
    1401481, -- Dù Chồn Chill
    1401482, -- TV Anime DAN DA DAN Parachute
    1401483, -- Dù C9S27
    1401484, -- Dù Lượn Shuriken
    1401485, -- Dù Bóng Ma Anh Quốc
    1401486, -- Dù The King of Fighters
    1401487, -- Dù Lượn Vũ Khúc
    1401488, -- Dù Bảo Thạch
    1401489, -- Dù Chuỗi Mùa Giải (2026H1)
    1401490, -- Dù S28
    1401491, -- Dù Trò Chơi Chúa Hề Lém Lĩnh
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
    1401492, -- Dù Apollo
    1401493, -- Dù Hacker Lạnh Lùng
    1401494, -- Dù Hội Tụ Đa Chiều
    1401495, -- Catch! Teenieping Parachute
    1401496, -- SAKAMOTO TARO Parachute
    1401497, -- Nakiri Ayame Parachute
    1401498, -- Dù S29
    1401499, -- Toxic Parachute
    1401500, -- Dù Red (Tròn)
    1401511, -- Dù Mèo Tinh Nghịch
    1401513, -- Dù San Martin FC
    1401515, -- Dù Mắt Quỷ
    1401516, -- Dù Sóng Đêm
    1401517, -- Dù Quả Quýt
    1401519, -- Dù Gấu Ngáy Ngủ
    1401520, -- Dù Hậu Duệ Đế Vương
    1401521, -- Dù Mây Cuộn
    1401526, -- Dù Hoa Văn Tráng Lệ
    1401527, -- Dù Trái Tim Biển Cả
    1401528, -- Dù Hành Tinh Mẹ
    1401529, -- Dù Hoàng Tử Ánh Kim
    1401530, -- Dù Giáp Gai
    1401531, -- Dù Vùng Nguy Hiểm
    1401532, -- Dù Ốc Biển
    1401534, -- Dù Vịt Vàng B.Duck
    1401538, -- Dù Thỏ Dịu Dàng
    1401540, -- Dù Yeti
    1401541, -- Dù Pixel Sắc Màu
    1401542, -- Dù Mỹ Vị
    1401543, -- Dù I Love Tao Kae Noi
    1401544, -- Dù Vẹt Baby
    1401545, -- Dù U.F.O
    1401546, -- Dù Baby Shark
    1401547, -- Dù Gấu Nhồi Bông
    1401548, -- Dù Mèo Nghiêm Túc
    1401549, -- Dù Vinh Quang Trường Tồn
    1401551, -- Dù Nữ Vương Khôi Giáp
    1401554, -- Dù Khủng Long Pixel
    1401555, -- Dù Cánh Bướm Hoàng Gia
    1401556, -- Dù Hành Trình Ngọt Ngào
    1401610, -- Dù Chúc Mừng Sinh Nhật
    1401611, -- Dù Sân Khấu Lấp Lánh
    1401613, -- Dù Thẩm Phán Anubis
    1401615, -- Dù Thần Horus
    1401616, -- Dù One Plus
    1401617, -- Dù Sư Tử Hống
    1401618, -- Dù Facebook
    1401619, -- Dù Bùa Hộ Mệnh Pharaoh
    1401620, -- Dù Pharaoh (Xanh)
    1401621, -- Dù Huyết Nha
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    1401622, -- Dù LINE FRIENDS
    1401623, -- Dù PMNC 2021
    1401624, -- Dù Poseidon
    1401625, -- Dù Công Chúa Bộ Lạc
    1401628, -- Dù Phượng Hoàng Adarna Ảo Diệu
    1401629, -- Dù Thiếu Nữ Sáng Thế
    1401811, -- Giannis Parachute
    1401813, -- Dù Hành Trình Anh Hùng
    1401814, -- Dù Rock 'n' Roll
    1401815, -- Dù Chỉ Huy Chiến Trường
    1401816, -- Dù BURGER KING
    1401817, -- Dù Chiến Binh Huyết Ưng
    1401820, -- Dù Cá Chuồn
    1401822, -- Dù Quái Thú Đầm Lầy
    1401823, -- Dù Lãnh Chúa Phong
    1401824, -- Dù Hộp Quà
    1401826, -- Dù - Mối Tình Đầu
    1401827, -- Dù Nữ Hoàng Cà Phê
    1401828, -- Dù Vệ Binh Cổ Đại
    1401829, -- Dù Cơn Giận Của Thần
    1401832, -- Dù C4S10
    1401833, -- Dù Quái Thú Mê Cung
    1401835, -- Dù Poker Đối Kháng
    1401836, -- Dù Trò Chơi Chú Hề
    1401837, -- Dù Huyễn Ảnh
    1401838, -- Dù BLUE LOCK
    1401839, -- Dù Ford
    1401840, -- Dù Harley-Davidson®
    1401841, -- Dù Hoa Hồng Cốt
    1401842, -- Dù Song Tử
    1401843, -- Dù Lượn Vòng Nguyệt Quế
    1401844, -- Parachute(Pubniku)
    1401845, -- Dù S30
    1401846, -- Dù Sự Kiện Trial of Fire

    -- [ TÀU LƯỢN / VÁN TRƯỢT / THIẾT BỊ BAY (Gliders/Hoverboards) ]
    4151001, -- Dù (Xanh)
    4151002, -- Hiệu ứng nhảy dù (Vàng)
    4151003, -- Khói Lượn Dù (Hồng)
    4151004, -- Khói lượn xanh
    4151006, -- Khói lượn cầu vồng
    4151010, -- Thiết bị bay Bằng Chíu
    4151012, -- Ván Trượt Chu Kỳ
    4151013, -- Ván Trượt Tuyết
    4151014, -- Ván trượt CHU KỲ 2
    4151015, -- Khói Lượn Dù Chúc Mừng (3 màu)
    4151017, -- Ván trượt Trái Tim Rừng Xanh
    4151018, -- Ván trượt Sinh Nhật
    4151019, -- Tàu Lượn Chiến Thần Tình Yêu
    4151020, -- Ván Trượt Cảnh Vệ C3
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
    4151021, -- Tàu Lượn Sứ Giả Của Thần
    4151022, -- Tàu Lượn Cánh Vàng
    4151023, -- Ván Trượt Hợp Tác Messi
    4151024, -- Tàu Lượn Giáo Sĩ Đỏ Thẫm
    4151025, -- Tàu Lượn Diều Giấy
    4151026, -- Ván Trượt Đại Sư Võ Hồn
    4151027, -- Ván Trượt Cycle 4
    4151028, -- Ván Trượt Giọt Lệ Huyết
    4151029, -- Tàu Lượn Nữ Đế Ánh Sáng
    4151030, -- Tàu Lượn Ma Vương Huyết Hồn
    4151031, -- Tàu Lượn Khủng Long Túi Tiền
    4151032, -- Tàu Lượn Cánh Rồng Đỏ Thẫm
    4151034, -- Cân Đẩu Vân
    4151035, -- Tàu Lượn Giao Hưởng Gió
    4151036, -- Ván Trượt Máy Dập Sóng
    4151037, -- Ván Trượt CYCLE 5
    4151038, -- Dù Lượn Ngọc Trai Tuyệt Hảo
    4151040, -- Ván trượt Thợ Săn Điện Quang
    4151041, -- Dù Lượn Xương Xanh
    4151042, -- Tàu Lượn Công Chúa Công Nghệ
    4151043, -- Tàu Lượn Công Chúa Công Nghệ
    4151044, -- Ván Trượt Cá Mập
    4151045, -- Dù Lượn Mùa Đông Hoàng Gia
    4151046, -- Ván Trượt Lưỡi Dao Trời Xanh
    4151056, -- Dù Lượn Mùa Đông Hoàng Gia
    4151057, -- Ván Trượt Hỏa Hồ Ly
    4151058, -- Dù Lượn LINE FRIENDS
    4151059, -- Ván Trượt Xuyên Mây
    4151060, -- Dù Lượn Xà Kim
    4151061, -- Ván Trượt CYCLE 6
    4151062, -- Khói Lượn Dù Zanmang Loopy
    4151063, -- SPY×FAMILY Tàu Lượn Bond
    4151064, -- Dù Lượn Thiên Sứ
    4151065, -- Dù Lượn Thiên Sứ
    4151066, -- Dù Lượn Đế Vương Thần Vực
    4151067, -- Dù Lượn Kính Vạn Hoa
    4151068, -- Tàu Lượn Chúa Tể Gai Độc
    4151069, -- Tàu Lượn Tinh Vân Sấm Sét
    4151070, -- Tàu Lượn Kỵ Binh Thần Giáp
    4151071, -- Dù Lượn Vệ Thần Tình Ái
    4151072, -- Dù Lượn Ngao Du Vũ Trụ
    4151073, -- Dù Lượn Neon Huyền Bí
    4151074, -- PUBGM X NewJeans Glider
    4151075, -- Dù Lượn Vệ Thần Tình Ái
    4151076, -- Tàu Lượn Cửu Phong Thiên Tôn
    4151077, -- Máy Bay
    4151078, -- Tàu Lượn Hải Mã Sắt
    4151079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm
    4151080, -- Ván Trượt Cycle 7
    4151083, -- Dù Lượn Long Cốt
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
    4151084, -- Hồng Hỏa Diệm - Kar98 (Cấp 8)
    4151085, -- Dù Lượn Cánh Thép Xuyên Không
    4151086, -- DP Drift Parachute
    4151087, -- Dù Lượn Long Cốt
    4151089, -- Dù Lượn Hắc Điểu 
    4151090, -- Dù Lượn Giấc Mộng Ngọt Ngào
    4151091, -- Tàu Lượn Nhà Khám Phá Vũ Trụ
    4151092, -- Dù Lượn Lam Sư Tinh Hà
    4151093, -- Dù Lượn Ngọc Lang Thiên Giới
    4151094, -- Ván Trượt CYCLE 8
    4151095, -- Dù Lượn Đôi Cánh Anukhra
    4151096, -- Dù Lượn Đôi Cánh Pharaoh
    4151097, -- Tàu Lượn Siêu Thú Ghidorah
    4151098, -- Dù Lượn Thời Quang Khả Biến
    4151099, -- Dù Lượn Vương Quyền Hắc Ám
    4151103, -- Dù Lượn Chiến Xa Tinh Tú
    4151104, -- Tàu Lượn Thiết Bị ODM
    4151105, -- Dù Lượn Định Mệnh Huyết Chú
    4151106, -- Dù Lượn Quang Ảo Điện Từ 
    4151107, -- Dù Lượn Chiến Xa Tinh Tú
    4151108, -- Tàu Lượn Laserbreak
    4151109, -- Tàu Lượn Băng Thần
    4151110, -- Tàu Lượn Long Thánh
    4151111, -- Tàu Lượn Thợ Săn Phản Lực
    4151112, -- Tàu Lượn Tà Thần Mỹ Quang
    4151113, -- Ván Trượt CYCLE 9
    4151114, -- Tàu Lượn Long Thánh
    4151115, -- Tàu Lượn Băng Thần
    4151117, -- Tàu Lượn Preondactyl
    4151118, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151119, -- Dù Lượn Chổi Phép Thuật
    4151120, -- Dù Lượn Long Kính
    4151121, -- Mikey Glider
    4151122, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151123, -- Tàu Lượn Băng Linh Lưu Ly
    4151124, -- Tàu Lượn Huyết Dực Tử Thần
    4151125, -- Tàu Lượn Vệ Binh Ngân Hà
    4151126, -- Tàu Lượn Giải Trí
    4151127, -- Tàu Lượn Linh Mộc Vĩnh Cửu
    4151128, -- Tàu Lượn Thần Quang
    4151129, -- Ván Trượt Chuỗi Mùa Giải (2026H1)
    4151130, -- Tàu Lượn Nue
    4151131, -- Tàu Lượn Phượng Hoàng Đế Vương
    4151132, -- Tàu Lượn Huyết Dực Hắc Điểu
    4151133, -- Tàu Lượn Dịch Chuyển Không Gian
    4151134, -- Dù Lượn Đa Vũ Trụ
    4151135, -- SAKAMOTO TARO Glider
    4151138, -- Tàu Lượn Sấm Sét Đỏ
    4151139, -- Tàu Lượn Hư Không
    4151140, -- Tàu Lượn Song Tử
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
    4151141, -- Tàu Lượn Cerberus
    4151142, -- Tàu Lượn Ngọc Trai
    4151143, -- Tàu Lượn Song Tử
    202408087,
    202408061,
    1102001001,
    4152031, -- Tàu Lượn Ma Vương Huyết Hồn
    4152035, -- Cân Đẩu Vân
    4152036, -- Windborne Euphony Glider
    4152037, -- Ván Trượt Máy Dập Sóng
    4152038, -- Ván Trượt CYCLE 5
    4152039, -- Tàu Lượn Ngọc Trai Tuyệt Hảo
    4152041, -- Boxerbolt Hoverboard (Shop)
    4152042, -- Blueyonder Glider
    4152043, -- Agile Charmer Glider
    4152044, -- Agile Charmer Glider
    4152045, -- Chilly Perch Glider
    4152046, -- Foxy Flare Hoverboard
    4152058, -- LINE FRIENDS Glider (Shop)
    4152059, -- Cloud Piercer Hoverboard (Shop)
    4152060, -- Golden Wings Glider (Shop)
    4152061, -- CYCLE 6 Skateboard (Shop)
    4152063, -- Tàu Lượn Bond SPY×FAMILY (Cửa Hàng)
    4152066, -- Dù Lượn Đế Vương Thần Vực (Cửa Hàng)
    4152067, -- Tàu Lượn Kính Vạn Hoa (Cửa Hàng)
    4152068, -- Tàu Lượn Chúa Tể Gai Độc (Cửa Hàng)
    4152069, -- Tàu Lượn Tinh Vân Sấm Sét (Cửa Hàng)
    4152070, -- Tàu Lượn Kỵ Binh Thần Giáp (Cửa Hàng)
    4152076, -- Tàu Lượn Cửu Phong Thiên Tôn (Cửa Hàng)
    4152077, -- Tàu Lượn (Cửa Hàng)
    4152078, -- Tàu Lượn Hải Mã Sắt (Cửa Hàng)
    4152079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm (Cửa Hàng)
    4152080, -- Ván Trượt CYCLE 7 (Cửa Hàng)
    4152092, -- Tàu Lượn Lam Sư Tinh Hà (Cửa Hàng)
    4152093, -- Tàu Lượn Ngọc Lang Thiên Giới (Cửa Hàng)
    4152094, -- Ván Trượt CYCLE 8 (Cửa Hàng)
    4152095, -- Dù Lượn Đôi Cánh Anukhra
    4152096, -- Dù Lượn Đôi Cánh Pharaoh
    4152097, -- Tàu Lượn Siêu Thú Ghidorah
    4152098, -- Dù Lượn Thời Quang Khả Biến
    4152099, -- Dù Lượn Vương Quyền Hắc Ám
    4152116, -- Tàu Lượn Long Thánh (Sảnh Một Người)

    -- ==============================================================================
    -- 3. TRANG PHỤC (OUTFITS), X-SUIT & PHỤ KIỆN
    -- ==============================================================================
    -- [ X-SUIT ]
    1407895, -- X-Suit Quạ Huyết (7 Sao)
    1407856, -- X-Suit Phượng Hoàng (7 Sao)
    1405628, -- X-Suit Pharaoh Vàng (6 Sao)
-- Dump by Shadow TG SHD_CHT
    1406469, -- X-Suit Pharaoh Vàng (7 Sao)
    1405870, -- X-Suit Quạ Huyết (6 Sao)
    1407140, -- X-Suit Poseidon (7 Sao)
    1407142, -- X-Suit Silvanus (7 Sao)
    1407141, -- X-Suit Bão Tuyết (7 Sao)
    1407550, -- X-Suit Ánh Sáng Cầu Vồng (7 Sao)
    1406638, -- X-Suit Hề Bí Ẩn (6 Sao) [Đen]
    1406641, -- X-Suit Hề Bí Ẩn (6 Sao) [Trắng]
    1406872, -- X-Suit Chúa Tể Âm Ty (7 Sao)
    1406971, -- X-Suit Marmoris (7 Sao)
    1407103, -- X-Suit Fiore (7 Sao)
    1407219, -- X-Suit Ignis (7 Sao)
    1407366, -- X-Suit Galadria (7 Sao)
    1407512, -- X-Suit Anukhra (7 Sao)
    1407625, -- X-Suit Dravion (7 Sao) [Nam]
    1407667, -- X-Suit Dravion (7 Sao) [Nữ]

    -- [ OUTFITS ]
    1407870, -- Bộ Nữ Thần Không Gian
    1407871, -- Bộ Thám Tử Đa Vũ Trụ
    1407812, -- Bộ Vệ Binh Hoang Dã
    1407758, -- Bộ Tiên Nữ Mùa Đông
    1407286, -- Bộ Mèo Cyber Tinh Nghịch
    1407329, -- Bộ Ánh Sáng Tĩnh Lặng
    1407391, -- Bộ Nữ Bá Tước Ma Cà Rồng
    1407392, -- Bộ Kẻ Phá Hoại Man Rợ
    1407387, -- Bộ Tử Thần Tận Thế
    1407440, -- Bộ Kẻ Chinh Phục Bắc Cực
    1406985, -- Bộ Người Tình Bãi Biển
    1407470, -- Bộ Thiên Thần Nổi Loạn
    1407471, -- Bộ Cực Quang Nanh Ngọc
    1407522, -- Bộ Hậu Duệ Tiên Cát
    1407330, -- Bộ Đô Đốc Bóng Ma
    1407523, -- Bộ Uy Quyền Tà Ác
    1407558, -- Bộ Thái Dương Thăng Hoa
    1407559, -- Bộ Ánh Sáng Nguyệt Cung
    1407572, -- Bộ Huyết Dạ Hoàng Hôn
    1407682, -- Bộ Kén Ẩn Sĩ
    1407695, -- Bộ Lễ Tình Nhân Rùng Rợn
    1407696, -- Bộ Lăng Kính Thăng Hoa
    1407632, -- Bộ Hắc Dạ Tà Ác
    1407573, -- Bộ Bóng Ma Điện Tử
    1406398, -- Bộ Bóng Ma Rực Lửa
    1406399, -- Bộ Kỵ Binh Oai Vệ
    1406482, -- Bộ Chúa Tể Gai Góc
    1406483, -- Bộ Tinh Vân Sấm Sét
    1406555, -- Bộ Khuôn Mặt Địa Ngục
    1406573, -- Bộ Thiên Nga Bóng Ma
    1406574, -- Bộ Quan Tòa Vũ Trụ
    1406656, -- Bộ Trưa Đẫm Máu
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    1406657, -- Bộ Đô Đốc Biển Sao
    1406742, -- Bộ Đạo Sư Bạc
    1406744, -- Bộ Hiệp Sĩ Thái Dương
    1406789, -- Bộ Bóng Ma Địa Ngục
    1406823, -- Bộ Giọt Nguyệt Bất Diệt
    1406824, -- Bộ Kẻ Thù Nhuốm Máu
    1406897, -- Bộ Ác Mộng Đỏ Thẫm
    1407277, -- Trang Phục Hỏa Thần Cổ Ngữ
    1406891, -- Trang Phục Linh Hồn Xác Ướp
    1405623, -- Bộ Xác Ướp Vàng
    1400687, -- Bộ Xác Ướp Trắng
    1407618, -- Bộ Thực Hồn Bắc Cực (Polar Spectrophage)

    -- [ Dragon Ball Super Collab ]
    1406937, -- Trang Phục Nhân Vật Super Saiyan Son Goku
    1406938, -- Trang Phục Nhân Vật Frieza
    1406939, -- Trang Phục Nhân Vật Son Goku
    1406947, -- Trang Phục Nhân Vật Vegeta
    1406948, -- Trang Phục Nhân Vật Super Saiyan Vegeta
    1406950, -- Trang Phục Beerus
    1406951, -- Trang Phục Ma Bư
    1406952, -- Trang Phục Quy Lão Kame
    1406953, -- Trang Phục Nhân Vật Gohan Siêu Cấp
    1406954, -- Trang Phục Nhân Vật Piccolo
    1407264, -- Trang Phục Nhân Vật Vegito
    1407265, -- Trang Phục Nhân Vật Vegito Siêu Saiyan
    1407266, -- Trang Phục Nhân Vật Vegito Siêu Saiyan Xanh
    1407267, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh
    1407268, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh (Bị Thương)
    1407269, -- Trang Phục Nhân Vật Vegeta Super Saiyan Xanh
    1407270, -- Trang Phục Nhân Vật Vegeta Siêu Saiyan Xanh (Bị Thương)
    1407271, -- Trang Phục Nhân Vật Bulma

    -- [ Evangelion Collab ]
    1406385, -- Plugsuit Evangelion Shinji
    1406386, -- Plugsuit Evangelion Rei
    1406387, -- Plugsuit Evangelion Asuka
    1406388, -- Plugsuit Evangelion Mari
    1406389, -- Plugsuit Evangelion Kaworu

    -- [ Attack on Titan Collab ]
    1407563, -- Trang Phục Nhân Vật Eren Jaeger
    1407565, -- Trang Phục Nhân Vật Mikasa Ackermann
    1407566, -- Trang Phục Nhân Vật Armin Arlelt
    1407567, -- Trang Phục Titan Khổng Lồ (Armin)
    1407568, -- Trang Phục Nhân Vật Levi
    1407569, -- Trang Phục Titan Bọc Thép

    -- [ Kaiju No. 8 Collab ]
    1407672, -- Trang Phục Nhân Vật Kafka Hibino
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
    1407673, -- Trang Phục Kaiju No. 8
    1407674, -- Trang Phục Nhân Vật Kikoru Shinomiya
    1407675, -- Trang Phục Kaiju No. 9
    1407676, -- Trang Phục Kaiju No. 10
    1407677, -- Trang Phục Nhân Vật Mina Ashiro
    1407678, -- Trang Phục Nhân Vật Reno Ichikawa
    1407679, -- Trang Phục Nhân Vật Soshiro Hoshina

    -- [ BlackPink & Kpop Collabs ]
    1406132, -- Trang phục DDU-DU DDU-DU ROSÉ
    1406133, -- Trang phục DDU-DU DDU-DU JENNIE
    1406134, -- Trang phục DDU-DU DDU-DU JISOO
    1406135, -- Trang phục DDU-DU DDU-DU LISA
    1406161, -- Trang phục How You Like That ROSÉ
    1406162, -- Trang phục How You Like That JENNIE
    1406163, -- Trang phục How You Like That JISOO 
    1406164, -- Trang phục How You Like That LISA
    1406178, -- Trang phục Lovesick Girls ROSÉ
    1406179, -- Trang phục Lovesick Girls JENNIE
    1406180, -- Trang phục Lovesick Girls JISOO
    1406181, -- Trang phục Lovesick Girls LISA
    1407346, -- PUBGM X NewJeans MINJI Set
    1407347, -- PUBGM X NewJeans HANNI Set
    1407348, -- PUBGM X NewJeans HAERIN Set
    1407349, -- PUBGM X NewJeans DANIELLE Set
    1407350, -- PUBGM X NewJeans HYEIN Set
    1407745, -- Trang Phục RAMI (Babymonster)
    1407746, -- Trang Phục ASA (Babymonster)
    1407747, -- Trang Phục AHYEON (Babymonster)
    1407748, -- Trang Phục RORA (Babymonster)
    1407749, -- Trang Phục CHIQUITA (Babymonster)
    1407750, -- Trang Phục PHARITA (Babymonster)
    1407751, -- Trang Phục RUKA (Babymonster)
    1407826, -- Trang Phục PUBG MOBILE × aespa KARINA
    1407827, -- Trang Phục PUBG MOBILE × aespa GISELLE
    1407828, -- Trang Phục PUBG MOBILE × aespa WINTER
    1407829, -- Trang Phục PUBG MOBILE × aespa NINGNING
    1407687, -- Trang Phục G-DRAGON PEACEMINUSONE
    1407688, -- Trang Phục Sân Khấu của G-DRAGON

    -- [ CÁC COLLAB NỔI BẬT KHÁC (Messi, Lý Tiểu Long, SPYxFAMILY...) ]
    1406648, -- Trang Phục Biểu Tượng Bóng Đá Messi
    1406649, -- Trang Phục Huyền Thoại Siêu Sao Messi
    1406728, -- Trang Phục Kung Fu Lý Tiểu Long
    1406729, -- Trang Phục Chuyên Gia Cận Chiến Lý Tiểu Long
    1406730, -- Trang Phục Rồng Gầm Lý Tiểu Long
    1406731, -- Trang Phục Võ Sĩ Lý Tiểu Long
    1407206, -- SPY×FAMILY Trang Phục Hoàng Hôn
    1407401, -- C.C. Set
    1407402, -- Kallen Kozuki Set
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
    1407404, -- Suzaku Kururugi Set
    1407405, -- ZERO Set
    1407408, -- Emperor Lelouch Set
    1407769, -- Okarun(transformed) Set
    1407770, -- Okarun Set
    1407771, -- Momo Set
    1407772, -- Jiji(transformed) Set
    1407773, -- Aira Set
    1407794, -- Trang Phục Nhân Vật John Shelby
    1407795, -- Trang Phục Nhân Vật Arthur Shelby
    1407796, -- Trang phục Thomas Shelby
    1407798, -- Trang Phục Nhân Vật Iori Yagami
    1407800, -- Trang Phục Nhân Vật Mai Shiranui
    1407801, -- Trang Phục Nhân Vật Nakoruru
    1407846, -- Trang Phục Nhân Vật Kimono Ryomen Sukuna
    1407848, -- Trang Phục Nhân Vật Suguru Geto
    1407901, -- Trang Phục Nhân Vật Isagi Yoichi
    1407902, -- Trang Phục Nhân Vật Bachira Meguru

    -- [ Set Đồ Đỏ Tự Nhiên & Siêu VIP của Game ]
    1405160, -- Huyền Thoại Godzilla
    1405161, -- Siêu Thú Ghidorah
    1405186, -- Bộ Đồ Godzilla
    1405662, -- Trang phục Giáp Samurai
    1405663, -- Trang phục Sát Thủ Bóng Đêm
    1406020, -- Trang phục Quái Thú
    1406398, -- Trang phục Hỏa Diệm Ma Giáp
    1406399, -- Trang phục Kỵ Binh Thần Giáp
    1406456, -- Trang Phục Anh Hùng Truyền Thuyết
    1406568, -- Trang Phục Nữ Hoàng Bóng Đêm
    1406569, -- Trang Phục Minh Vương Hành Quyết
    1406732, -- Trang Phục Nữ Đế Hoàng Kim
    1406733, -- Trang Phục Hoàng Đế Hoàng Kim
    1406764, -- Trang Phục Thiếu Nữ Đỏ Rực

    -- ==============================================================================
    -- 4. ÁO, QUẦN, GIÀY ĐẸP & TDM (PHONG CÁCH CỰC CHẤT)
    -- ==============================================================================
    -- [ BAPE & ALAN WALKER ]
    1400569, -- BAPE MIX CAMO HOODIE
    1400650, -- BAPE MIX CAMO SHORTS
    1400651, -- BAPE STA MID
    1404000, -- BAPE City Camo Hoodie
    1404002, -- BAPE City Camo Pants
    1404003, -- BAPE Sta Mid
    1404048, -- Áo BAPE X PUBGM CAMO
    1404049, -- Áo Hoodie cá mập BAPE X PUBGM CAMO
    1404050, -- Quần BAPE X PUBGM CAMO
    1404051, -- Giày BAPE X PUBGM CAMO
    1404016, -- Alan Walker T-shirt
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    1404017, -- Alan Walker Hoodie
    1404042, -- Trang phục Alan Walker
    1404043, -- Áo Alan Walker
    1404044, -- Quần Alan Walker
    1404045, -- Giày Alan Walker
    1404340, -- Trang phục Alan Walker 2021
    1403038, -- Alan Walker Mask
    1403064, -- Khẩu trang Alan Walker

    -- [ Đồ TDM Phổ Biến (Khăn bịt mặt, Áo Lính, Áo Khoác Đen...) ]
    402001, -- Khăn rằn sinh tồn
    402037, -- Khăn quàng cao bồi
    402043, -- Khăn quàng PUBG (Đỏ-Đen)
    402045, -- Khăn quàng PUBG (Chiến thuật)
    1400158, -- Mặt Nạ Hockey
    1402005, -- Mysterious Leather Mask
    1403100, -- Mặt nạ người leo núi
    403010, -- Áo Ba Lỗ Bẩn (Trắng)
    403028, -- Áo Trench coat (Màu đen)
    403181, -- Áo lính sa mạc
    403182, -- Áo Hoodie săn mồi (Đen)
    403183, -- Áo Hoodie biệt kích (Trắng)
    403192, -- Áo khoác bomber
    404006, -- Quần Jeans (Nâu)
    404008, -- Quần lính (Ka-ki)
    404013, -- Quần lính (Rằn ri)
    404015, -- Quần Jeans Bó (Màu Lam)
    404026, -- Quần túi hộp (Màu be)
    404028, -- Quần túi hộp (Màu đen)
    404084, -- Quần thể thao ngắn (Đen)
    404100, -- Quần người ẩn nấp (Đen)
    405001, -- Giày đế mềm (Màu trắng)
    405002, -- Giày thể thao cổ cao
    405019, -- Giày lính chim ưng (Đen)
    405044, -- Giày đế mềm (Đen)
    1400013, -- Quần Jeans Mỹ

    -- [ CÁC ÁO LẺ VIP (Collab, Siêu Xe) ]
    1404142, -- Áo thun THE WALKING DEAD (Trắng)
    1404143, -- Áo thun THE WALKING DEAD (Đen)
    1404218, -- Áo Hoodie COVERNAT (Trắng)
    1404219, -- Áo Hoodie COVERNAT (Đen)
    1404326, -- Áo thun Xiaomi
    1404327, -- Áo thun OnePlus
    1404405, -- Áo Đấu Hợp Tác Messi × PUBG MOBILE
    1404406, -- Áo Thun Lý Tiểu Long
    1404411, -- Hoodie Ducati
    1404412, -- Giày Ducati Corse City C2
    1404413, -- Quần Ducati Sport C2
    1404414, -- Áo Khoác Ducati Speed Evo C2
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
    1404426, -- Áo PMGC 2023
    1404427, -- Quần Người Chinh Phục Pagani
    1404428, -- Giày Người Chinh Phục Pagani
    1404508, -- Áo Hoodie Mr.Beast
    1400324, -- áo b
    1400325, -- áo a
    452001, 452002, 452003, -- Găng Tay (Gloves)
    
        -- [ HÀNH ĐỘNG ]
    12201301, -- Hành động Sát thủ Gothic
    12216101, -- Hành động Võ sĩ Huyết Ưng
    12212201, -- Hành động Sát thủ Cực Ám
    12219207, -- Hành động Đại tướng Thiên Ngưu
    12209001, -- Hành động Võ sĩ (Samurai)
    12219561, -- Hành động Áo choàng Đỏ thẫm
    12210001, -- Hành động Cái chạm của Tử thần
    12219022, -- Hành động Thiết vệ Gai góc
    12208801, -- Hành động Dũng sĩ Bán thần
    12210801, -- Hành động Thợ săn Vỏ bạc
    12200701, -- Hành động Du hành Không thời gian
    12219242, -- Hành động Dạo bước Bầu trời
    12206001, -- Hành động Hoa linh Đồng xanh
    12205401, -- Hành động Vua của muôn thú
    12205201, -- Hành động Trái tim Cự thú
    12212601, -- Hành động Sát lục Thần bí
    12205601, -- Hành động Linh hồn Cự thú
    12219208, -- Hành động Hầu vương Cyber
    12212001, -- Hành động Võ thánh
    12206801, -- Hành động Hải long Thần bí
    12209801, -- Hành động Ngự linh sư
    12211401, -- Hành động Nữ phù thủy Băng tuyết
    12207001, -- Hành động Du hành Biển sao
    12211801, -- Hành động Chúa tể Trật tự
    12207901, -- Hành động Hải vương Quyến rũ
    12203401, -- Hành động Kỷ niệm Ảo ảnh
    12204001, -- Hành động Chú hề (Ngày Cá tháng Tư)
    12201801, -- Hành động Người bảo vệ Vùng tuyết
    12215601, -- Hành động Siêu nhân Hằng tinh
    12215532, -- Hành động Lãnh chúa Ngọn lửa
    12213201, -- Hành động Kế hoạch Ngày mai
    12215529, -- Hành động Kỵ sĩ Đua xe
    12219053, -- Hành động Nữ hoàng Trân bảo
    12204601, -- Hành động Thiên hạ Bố võ
    12215701, -- Hành động Hành tinh Vượn người
    12219003, -- Hành động Bóng tối Thần linh
    12219004, -- Hành động Ngân hồn Rực lửa
    12219009, -- Hành động Mê hoặc Rực lửa
    12219216, -- Hành động Tế tư Héo úa
    
    
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
    -- tóc mặt tùm lum
    1404198, 1410085, 1404366, 1403137, 1410480, 1403028, 1400158, 40605011, 1404323, 1406001, 1403002,

-- ==============================================================================
    -- MŨ GIÁP VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1502001183, -- Godzilla Helmet (Lv. 1)
    1502001194, -- Mũ MECHAGODZILLA (Cấp 1)
    1502001093, -- Mũ Thẩm Phán Anubis (Cấp 1) - Pharaoh
    1502001305, -- Mũ Giáp Siêu Nhân Thép (Cấp 1)
    1502001320, -- Mũ Giáp Biểu Tượng Bóng Đá Messi (Cấp 1)
    1502001105, -- Mũ Tàng Hình (Cấp 1)
    1502001364, -- Mũ Giáp PMGC 2023 (Cấp 1)
    1502001373, -- Mũ Giáp LINE FRIENDS BROWN (Cấp 1)
    1502001402, -- APEACH Helmet (LV.1)
    1502001403, -- Bellygom Helmet (LV.1)
    1502001427, -- Opanchu Helmet (Lv.1)
    1502001443, -- Mũ Giáp Sóng Âm Cuồng Loạn (Cấp 1)
    1502001450, -- Mũ Giáp Cún Tinh Nghịch (Cấp 1)
    1502001471, -- Turbo Granny (Beckoning cat) Helmet (Lv. 1)
    1502001480, -- Mũ Giáp PUBG MOBILE × aespa (Cấp 1)
    1502001490, -- Nakiri Ayame Helmet (Lv.1)
    1502001495, -- Mũ BLUE LOCK (Cấp 1)
    1502001001, -- Mũ pizza nóng (Cấp 1)
    1502001004, -- Mũ Cyberpunk (Tím) (Cấp 1)
    1502001005, -- Mũ hộp sọ (Cấp 1)
    1502001046, -- Mũ Samurai - danh dự (Cấp 1)
    1502001058, -- Mũ bảo hiểm Monarch (Cấp 1)
    1502001064, -- Mũ bảo hiểm Thiên Sứ (Cấp 1)
    1502001073, -- Mũ Vệ Binh Robot (Cấp 1)
    1502001078, -- Mũ Ninja Sát Thủ (Cấp 1)
    1502001086, -- Mũ Chuột Tinh Nghịch (Cấp 1)
    1502001099, -- Mũ Corgi (Cấp 1)
    1502001115, -- Mũ Bọ Rùa (Cấp 1)
    1502001133, -- Mũ Bí Ngô Kinh Dị (Cấp 1)
    1502001145, -- Mũ Chú Lính Chì (Cấp 1)
    1502001154, -- Mũ Giáp Đại Bàng Tỏa Sáng (Cấp 1)
    1502001175, -- Mũ Vịt Vàng B.Duck (Cấp 1)
    1502001230, -- Mũ Rồng Công Nghệ (Cấp 1)
    1502001248, -- Mũ Người Mở Đường (Cấp 1)
    1502001264, -- Mũ Ét Ô Ét (Cấp 1)
    1502001276, -- Mũ Vũ Công Bí Ẩn (Cấp 1)
    1502001294, -- Mũ Giáp Ma Pháp Sư (Cấp 1)
    1502001301, -- Mũ Giáp Archon Lừng Lẫy (Cấp 1)
    1502001357, -- Mũ Giáp Son Goku (Cấp 1)
    1502001381, -- Mũ Giáp Hỏa Linh Chí Tôn (Cấp 1)
    1502001416, -- Mũ Giáp PMGC 2024 (Cấp 1)
    1502001453, -- 2025 Esports Helmet (Lv. 1)

    -- ==============================================================================
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    -- BA LÔ VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1501001174, -- Ba lô Pharaoh (Cấp 1)
    1501001220, -- Ba lô Huyết Nha (Cấp 1)
    1501001265, -- Ba lô Poseidon (Cấp 1)
    1501001548, -- Balo Thần Thoại Viễn Cổ (Cấp 1)
    1501001559, -- Balo Thanh Hoa Xà (Cấp 1)
    1501001567, -- Ba Lô Hỏa Linh Chí Tôn (Cấp 1)
    1501001577, -- Balo Đôi Cánh Vệ Thần (Cấp 1)
    1501001607, -- Balo Dơi Bóng Đêm (Cấp 1)
    1501001061, -- Ba lô Godzilla (Cấp 1)
    1501001062, -- Ba Lô Siêu Thú Ghidorah (Cấp 1)
    1501001082, -- Ba lô Genbu (Cấp 1)
    1501001112, -- Ba lô Pig Ngốc Nghếch (Cấp 1)
    1501001133, -- Ba lô Joker Khát Máu (Cấp 1)
    1501001243, -- Ba Lô Vịt Vàng B.Duck (Cấp 1)
    1501001273, -- Ba lô MECHAGODZILLA (Cấp 1)
    1501001304, -- Ba lô Ma Vương (Cấp 1)
    1501001331, -- Ba lô của Jinx (Cấp 1)
    1501001340, -- Ba Lô Hải Cẩu Tuyết (Cấp 1)
    1501001376, -- Ba lô Máy Hát Cổ Điển (Cấp 1)
    1501001400, -- Ba lô Baby Shark (Cấp 1)
    1501001463, -- Ba Lô BoBoiBoy (Cấp 1)
    1501001476, -- Ba Lô Biểu Tượng Bóng Đá Messi (Cấp 1)
    1501001480, -- Ba Lô Mì Indomie (Cấp 1)
    1501001487, -- Ba Lô Con Mắt Chết Chóc (Cấp 1)
    1501001521, -- Ba Lô Quy Lão Kame (Cấp 1)
    1501001539, -- Ba Lô PMGC 2023 (Cấp 1)
    1501001540, -- Ba Lô Gà Rán KFC (Cấp 1)
    1501001554, -- Ba Lô LINE FRIENDS SALLY (Cấp 1)
    1501001587, -- Ba Lô Đại Úy Loạn Thế (Cấp 1)
    1501001597, -- Bellygom Backpack (LV.1)
    1501001632, -- Opanchu Backpack (Lv.1)
    1501001643, -- Frieren&Mimic Backbag (Lv.1)
    1501001650, -- Ba Lô Titan Khổng Lồ Cấp 1
    1501001683, -- Ba Lô Balenciaga (Cấp 1)
    1501001715, -- SAKAMOTO TARO Backpack (Lv.1)
    1501001720, -- Ba Lô BLUE LOCK (Cấp 1)
    
        -- [ BALO, MŨ & DÙ LƯỢN ]
    1501001024, -- Balo Bá Tước
    1502001014, -- Mũ Đinh
    1502001439, -- mũ vương miện
    1502001069, -- mũ cương thi
    1502001023, -- mũ băng
    

    
    -- id bổ xung
    1400092, 1400101, 1400122, --tư lệnh
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
    1404191, -- quần bộ hành
    1405128, 1405129, 140224445, 140224445, -- crew
    1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 1502001508, 1502002508, 1502003508, 1411134, 1411133, 1411135, 1403771, 1403770, 1407994, 1407993, 1101006106, 1101006098, 4151145, 1903230, 1903231, 1903232, 1908117, 1908118, 1908119, 19116002, 19116003, 19116004, 1961070, 1961071, 1961072, 1961073, 1408045, 1408038, 1407990,1407922, -- Trang Phục Nữ Thần Ái Tình
    1407704, -- Trang Phục Cô Dâu Tinh Quái
    1400782, -- Trang phục băng tuyết
    1407614, -- Trang Phục Optimus Prime Transformers
    1407276, -- Trang Phục Vệ Thần Tình Ái
    1410356, -- Mặt Nạ Ma Vương Huyết Hồn
    40605012, -- Tóc Hai Chùm
    401035, -- Mũ cao bồi (Trắng)
}

_G.INS_BASE = 2000000000
_G.PKG_SLOT = 3
_G.MELEE_ID = 108
_G.HAT_SUB = 401
_G.MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } -- [FIX VIP] Đã xóa 502 và 505 để tách biệt hoàn toàn Mũ Bảo Hiểm khỏi Tóc/Mũ Thời Trang
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC     = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    return _G.AddOutfitEquippedCache
end

-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ

function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
    return res and R.resToIns[tonumber(res)] ~= nil
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or st == MELEE_ID
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end -- Bỏ qua nếu tắt Mod Skin
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isInjectedIns(insID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
    if F.isVehicleRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    F.clearWeaponEquippedMark(weaponID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("ذاكرة سكن", weaponID, "→", resID)
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
-- Dump by Shadow TG SHD_CHT
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return true end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)
-- Dump by Shadow TG SHD_CHT

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    -- [FIX VIP] Nếu tắt Mod Skin thì bỏ qua không load đèn gầm
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    F.vehicleAvatarTemper()
    
    -- [FIX VIP] Ép hiển thị Kính & Mặt Nạ liên tục mỗi 1 giây (Bất chấp việc nhặt mũ bảo hiểm)
    pcall(function()
        local char = F.getLocalChar()
        if char then F.matchApplyFaceWear(char) end
    end)

    local now = os.clock()
    if now - _vehTickLastApply < 5.0 then return end
    _vehTickLastApply = now
    F.applyVehicleSkinsToPC()
end

function F.startVehicleSkinTicker()
    pcall(function()
        if not _ticker then return end
        if _G.AddOutfitVehTickerId then return end
        if _ticker.AddTimerLoop then
            _G.AddOutfitVehTickerId = _ticker.AddTimerLoop(1.0, function()
                local fn = _G.AddOutfit and _G.AddOutfit.vehicleSkinTick
                if fn then pcall(fn) end
            end, -1, 1.0)
        end
    end)
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    if not (_G.LexusConfig and _G.LexusConfig.ModSkin == true) then return end
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("03153875433_outfit.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end

function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then cch[cacheInsKey] = ins end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        wparts[#wparts + 1] = string.format('    "%d": %d', wid, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    local hasCacheSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasCacheSlots = true; break end
    if hasCacheSlots then
        appendVehicleSlots(cch.vehicleSlots)
    elseif PERSIST.configVehicleSlots then
        appendVehicleSlots(PERSIST.configVehicleSlots)
    end
    table.sort(vparts)
    parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, vehicleSlots = {} }
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = tonumber(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "chassisLightMap" and type(v) == "table" then
                    out.chassisLightMap = {}
                    for vk, lv in pairs(v) do
                        local vid, lid = tonumber(vk), tonumber(lv)
                        if vid and lid and F.isChassisLightId(lid) then
                            out.chassisLightMap[vid] = lid
                        end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
            if n and n > 0 then
                local wid = tonumber(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        if res and res > 0 and not cch[s[2]] then
            local ins = R.resToIns[res]
            if ins then
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    if saved.weapons and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    local row = {
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            local idx = entity._DataCount
            if idx and entity._data[idx] then
                entity:LoadConfigForData(entity._data[idx], CDataTable.GetTableData)
            end
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end
-- Dump by Shadow TG SHD_CHT

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID)
    local wid = F.weaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

function F.injectAll(entity)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end -- Bỏ qua nếu tắt Mod Skin
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end
    local n, nNew = 0, 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        local had = R.resToIns[resID] ~= nil
        if F.injectOne(entity, resID, insID) then
            n = n + 1
            if not had then nNew = nNew + 1 end
            local c = F.cfg(resID)
            if GUN_SUB[F.subType(c)] or F.subType(c) == MELEE_ID then
                F.injectArmory(resID, insID)
            end
        end
    end
    if not _G.AddOutfitUnexpireDone then
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
        _G.AddOutfitUnexpireDone = true
        pcall(F.reviveExpiredOwned, entity)
    end
    F.mergeRevivedIntoMaps()
    F.sanitizeAllInjectedExpire()
    F.ensureInjectedResources()
    return n > 0
end

function F.refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
                    bag.bag_skin = insID
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                end
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

-- Dump by Shadow TG SHD_CHT
function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

function F.reapplyLobbyEquipped()
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    if cch.hatIns and F.isInjectedIns(cch.hatIns) then
        F.putOnHat(cch.hatIns)
    end
    if cch.maskIns and F.isInjectedIns(cch.maskIns) then
        F.putOnRoleWear(cch.maskIns)
    end
    if cch.glassIns and F.isInjectedIns(cch.glassIns) then
        F.putOnRoleWear(cch.glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    if cch.pantsIns and F.isInjectedIns(cch.pantsIns) then
        F.putOnRoleWear(cch.pantsIns)
    end
    if cch.shoesIns and F.isInjectedIns(cch.shoesIns) then
        F.putOnRoleWear(cch.shoesIns)
    end
    if cch.bagIns and F.isInjectedIns(cch.bagIns) then
        F.putOnRoleWear(cch.bagIns)
    end
    if cch.helmetIns and F.isInjectedIns(cch.helmetIns) then
        F.putOnRoleWear(cch.helmetIns)
    end
    if cch.parachuteIns then
        F.putOnParachute(cch.parachuteIns)
    end
    if cch.gliderIns then
        F.putOnGlider(cch.gliderIns)
    end
    if cch.glovesIns and F.isInjectedIns(cch.glovesIns) then
        F.putOnGloves(cch.glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                -- [FIX LỖI VIP] Tự động đắp lại Skin Mod khi game có dấu hiệu update súng ở sảnh
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            -- [FIX LỖI VIP] Khi Click vào ô vũ khí ở Sảnh, đợi game đổi súng gốc xong thì 0.3s sau đắp skin Mod lên lại
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            pcall(function()
                if F.injectAll(self) then
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isInjectedRes(v.resID) then
                local itemTab = tonumber(v.subTabType) or F.wardrobeTab(v.resID)
                if itemTab and itemTab == subTab then
                    if mainTab == PAGE_AVATAR or mainTab == PAGE_VEHICLE then return true end
                    if mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID) then return true end
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if F.isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            if F.isInjectedIns(tonumber(insID)) then
                F.takeOffInjected(insID)
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
-- Dump by Shadow TG SHD_CHT
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            -- 1. GHI ĐÈ DATA MẠNG (Chống lỗi không đồng bộ)
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            -- [LOGIC NGỦ ĐÔNG] - TỐI ƯU FPS TUYỆT ĐỐI
            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            -- Tạo ID định danh riêng biệt cho nhân vật hiện tại tránh trùng lặp
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                -- Lần đầu tiên ép hiển thị / Hoặc ID Skin bị thay đổi -> Chạy Full C++
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                -- Cập nhật Cache để vòng lặp sau đi vào Ngủ Đông
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true -- Bật cờ để gọi OnRep_BodySlotStateChanged (vẽ lại Mesh)
            else
                -- TRẠNG THÁI NGỦ ĐÔNG: Data đã đúng, Mesh 3D đã được render.
                -- Chỉ chạy hàm cực nhẹ CancelHide để chống Game tự ẩn khi nhặt Mũ bảo hiểm (1,2,3).
                -- BỎ QUA việc Render lại Mesh để tránh Drop FPS.
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        -- Gọi lệnh ép cho Mặt nạ (Mask)
        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        -- Gọi lệnh ép cho Mắt kính (Glass)
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
        -- Cập nhật hình ảnh 3D CHỈ KHI THOÁT KHỎI NGỦ ĐÔNG (Khi cần thiết)
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    local applied, found = false, false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local BackpackUtils = import("BackpackUtils")
        local function doSlot(slotEnum, res, levelFn, lastKey)
            res = tonumber(res) or 0
            if res <= 0 or not slotEnum then return end
            local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slotEnum)
            if not sync then return end
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
            local cur = tonumber(sync.ItemID) or 0
            local addID = tonumber(sync.AdditionalItemID) or 0
            if cur <= 0 and addID <= 0 then return end
            found = true
            local lvl = 1
            pcall(function()
                if levelFn then lvl = levelFn(addID > 0 and addID or cur) or 1 end
            end)
            if lvl < 1 then lvl = 1 end
            local target = F.levelSkinID(res, lvl)
            if target > 0 and cur ~= target then
                sync.ItemID = target
                comp:ChangeSlotSyncData(sync)
                applied = true
                EQUIP_APPLY[lastKey] = target
            end
        end
        doSlot(EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot, bagRes,
               BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
        doSlot(EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot, helmetRes,
               BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    end)
    return applied, found
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then return false end

    local applied, found = F.applyEquipSkinToComp(comp, bagRes, helmetRes)

    if applied then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
        return true
    end
    return found
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            F.applyEquipSkinToComp(self, bagRes, helmetRes)
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "تيشرت",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "سروال" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "حذاء" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "قفازات" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        ok = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) or ok
    end

    return ok or #entries == 0
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = F.resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = F.findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
    if target then return target end
    return currentGunId
end

function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local tmp_id = F.get_skin_id(current_gunid, MaxIt)
    tmp_id = tonumber(tmp_id) or 0
    if tmp_id <= 0 or MaxIt <= 0 then return false end
    
    local changedAny = false

    -- LOGIC 1: LẤY ID HÌNH ẢNH ĐANG HIỂN THỊ THỰC TẾ
    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    -- NẾU SÚNG CHÍNH CHƯA PHẢI LÀ SKIN VIP -> THAY ĐỔI DATA
    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    -- LOGIC 2: XỬ LÝ PHỤ KIỆN (ATTACHMENTS)
    if _G.LexusConfig.SkinAttachment and tmp_id >= 1000000 and _G.VIP_Attachments and _G.VIP_Attachments[tmp_id] then
        local attachSkinConfig = _G.VIP_Attachments[tmp_id]
        local baseAttachMap = _G.BaseAttachToIndex
-- Dump by Shadow TG SHD_CHT
        
        if attachSkinConfig and baseAttachMap then
            for AttachIdx = 0, 5 do 
                pcall(function()
                    local attachData = AttachmentArray:Get(AttachIdx)
                    if attachData then
                        local defineIDRef = slua.IndexReference(attachData, "defineID")
                        if defineIDRef then
                            local attachmentId = defineIDRef.TypeSpecificID
                            if attachmentId and attachmentId > 0 then
                                local baseAttId = attachmentId
                                if baseAttId > 1000000 then
                                    local strId = tostring(baseAttId)
                                    if #strId >= 9 then baseAttId = tonumber(string.sub(strId, 2, 7)) or baseAttId end
                                end

                                local mapIndex = baseAttachMap[baseAttId]
                                if mapIndex then
                                    local targetAttachId = attachSkinConfig[mapIndex]
                                    if targetAttachId and targetAttachId > 0 and targetAttachId ~= attachmentId then
                                        defineIDRef.TypeSpecificID = targetAttachId
                                        attachData.defineID = defineIDRef
                                        AttachmentArray:Set(AttachIdx, attachData)
                                        changedAny = true
                                        
                                        -- Xóa cache Phụ kiện cũ để game Load phụ kiện VIP
                                        if slua.isValid(wac) then
                                            if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(AttachIdx) end
                                            if wac.ClearMeshBySlot then wac:ClearMeshBySlot(AttachIdx, true, true) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    -- LOGIC 3: LỆNH THẦN THÁNH ÉP GAME VẼ LẠI MESH NGAY TRÊN TAY
    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                -- Nếu là súng mới nhặt, xóa cái vỏ súng cũ kĩ đi
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ

function F.onWeaponLuaInit(_, _, weapon)
    if _G.LicenseValid ~= true then return end
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    if _G.LicenseValid ~= true then return false end
    if not _avatarItemsRegistered then
        _avatarItemsRegistered = F.registerWeaponAvatarItems(char)
    end

    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end

    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    -- [HỆ THỐNG SMART WATCHER V3] Quét toàn bộ Súng trên tay & Súng trong Balo
    if not _G.SmartWeaponWatcherActive then
        _G.SmartWeaponWatcherActive = true
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerLoop then
                ticker.AddTimerLoop(0, function()
                    if not _G.LexusConfig.ModSkin then return end
                    
                    -- [CỜ NGỦ ĐÔNG IN-GAME]: Nếu đã ra Sảnh -> Ngủ luôn, không chạy gì hết!
                    if _G.AddOutfit and not _G.AddOutfit.isInRealMatch() then return end
                    
                    local pController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    if not pController or not slua.isValid(pController) then return end
                    local pChar = pController:GetPlayerCharacterSafety()
                    if not pChar or not slua.isValid(pChar) then return end
                    
                    -- Thay vì chỉ lấy súng trên tay, lấy luôn KHO VŨ KHÍ (Weapon Manager)
                    local WeaponManager = pChar:GetWeaponManager()
                    if not WeaponManager or not slua.isValid(WeaponManager) then return end
                    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
                    if not uWeaponList or not slua.isValid(uWeaponList) then return end
                    
                    local count = uWeaponList:Num()
                    -- Lặp qua từng khẩu súng bạn đang sở hữu (Súng 1, Súng 2, Lục, Dao)
                    for i = 0, count - 1 do
                        local wep = uWeaponList:Get(i)
                        if slua.isValid(wep) then
                            -- Kiểm tra data (synData) của súng xem đã là Data VIP chưa
                            local synSkinID = F.getSynMasterSkinID(wep)
                            local baseID = 0
                            pcall(function() baseID = wep:GetItemDefineID().TypeSpecificID end)
                            local tSkin = F.findTargetSkinForWeaponRes(baseID) or baseID
                            
                            -- NẾU DATA CHƯA PHẢI LÀ VIP -> Vừa lụm thẳng vào Balo -> Bắn lệnh Load ngầm!
                            -- HOẶC bật Skin Phụ Kiện -> Kiểm tra phụ kiện
                            if synSkinID ~= tSkin or _G.LexusConfig.SkinAttachment then
                                if _G.AddOutfit and _G.AddOutfit.applySkinToWeapon then
                                    _G.AddOutfit.applySkinToWeapon(wep)
                                end
                            end
                        end
                    end
                end, -1, 0.4) 
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
            end
        end)
    end

    -- BÁO CÁO HOÀN THÀNH: Nếu súng cầm trên tay đã xong xuôi thì khóa luồng gốc của Engine
    if isVisualMatched and not _G.LexusConfig.SkinAttachment then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false

function F.startMatchWatcher(char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur) -- [FIX VIP] Bổ sung lệnh gọi ép Kính & Mặt Nạ chạy liên tục giống Mũ
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
        end
    end)
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    if _G.LicenseValid ~= true then return false end
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
-- Ｄｕｍｐ • ｂｙ • Ｓｈａｄｏｗ shadow_cheatss
    PERF.lastBootstrapAt = now
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    F.cleanArmoryPollution()
    F.syncGlobalWearSkins()
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == true then
        F.syncVehicleCacheFromDataMgr()
        F.syncVehicleSlotsToDataMgr()
        pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
        F.startVehicleSkinTicker()
    end
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                if PERF.wearDoneThisMatch or PERF.matchActive then return end
                local char = F.getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.5, false, function() F.bootstrapMatch(char) end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
-- 𝕯𝖚𝖒𝖕 𝖇𝖞 𝕾𝖍𝖆𝖉𝖔w SHD_CHT
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
-- ᴅᴜᴍᴘ ʙʏ ꜱʜᴀᴅᴏᴡ ᴛɢ ꜱʜᴅ_ᴄʜᴛ
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._AddOutfitLobbyVehHooked then return end
        HallThemeUtils._AddOutfitLobbyVehHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if not _G.AddOutfitApplyingConfig and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setLobbyVehicleManual(F.vehicleSubType(res or R.insToRes[ins]), res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookGarageTheme()
    pcall(function()
        local TeamupHandler = require("client.network.Protocol.TeamupHandler")
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not TeamupHandler then return end
-- Ｄｕｍｐ_ｂｙ_Ｓｈａｄｏｗ shadow_cheatss
        
        -- Hook: Update Từng Slot Xe ở sảnh
        local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
        if o_send_update and not TeamupHandler._AddOutfitGarageUpdateHooked then
            TeamupHandler._AddOutfitGarageUpdateHooked = true
            TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Nếu đang trong trận thực sự -> Bỏ qua toàn bộ logic Gara Sảnh, trả về game gốc ngay lập tức!
                if F.isInRealMatch() then 
                    return o_send_update(slot_id, item_inst_id) 
                end

                if F.isInjectedIns(tonumber(item_inst_id)) then
                    local resID = R.insToRes[tonumber(item_inst_id)]
                    local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if not GarageThemeSystem then return end

                    GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                        inst_id = tonumber(item_inst_id),
                        res_id = resID
                    }

                    for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                        if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                            GarageThemeSystem.GarageVehicleInfo[k] = nil
                        end
                    end

                    pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end

                    local itemCfg = F.cfg(resID)
                    if itemCfg and DataMgr and DataMgr.UpdateVehicleSkin then
                        local subType = itemCfg.ItemSubType or itemCfg.itemSubType
                        DataMgr.UpdateVehicleSkin(subType, tonumber(item_inst_id))
                    end
                    if DataMgr then DataMgr.vst_skin = tonumber(item_inst_id) end
                    
                    pcall(function()
                        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                        if HallThemeUtils then
                            if HallThemeUtils.UpdateThemeVehicleShow then HallThemeUtils.UpdateThemeVehicleShow() end
                            if HallThemeUtils.ShowThemeVehicle then HallThemeUtils.ShowThemeVehicle() end
                        end
                    end)
                    return
                end
                return o_send_update(slot_id, item_inst_id)
-- 𝕯-𝖀-𝙼-𝕻 𝕭-𝖄 𝐒𝚖𝚫𝐃𝚯𝚯 SHD_CHT
            end
        end

        -- Hook: Update Hàng loạt xe ở sảnh
        local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
        if o_send_batch and not TeamupHandler._AddOutfitGarageBatchHooked then
            TeamupHandler._AddOutfitGarageBatchHooked = true
            TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Tương tự, chặn đứng khi đang trong trận
                if F.isInRealMatch() then 
                    return o_send_batch(instid_list) 
                end

                if type(instid_list) ~= "table" then
                    return o_send_batch(instid_list)
                end

                local hasInjected = false
                for slot_id, item_inst_id in pairs(instid_list) do
                    if F.isInjectedIns(tonumber(item_inst_id)) then
                        hasInjected = true
                        break
                    end
                end

                if not hasInjected then
                    return o_send_batch(instid_list)
                end

                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                for slot_id, item_inst_id in pairs(instid_list) do
                    local insID = tonumber(item_inst_id)
                    if F.isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        if insID ~= 0 and resID then
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                                inst_id = insID,
                                res_id = resID
                            }
                        else
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                        end
                    end
                end

                pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
-- 𝓓𝑢𝓶𝓹•𝓫𝔂•𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 shadow_cheatss
                    EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                end

                local nonInjected = {}
                for slot_id, item_inst_id in pairs(instid_list) do
                    if not F.isInjectedIns(tonumber(item_inst_id)) then
                        nonInjected[slot_id] = item_inst_id
                    end
                end
                if next(nonInjected) then
                    return o_send_batch(nonInjected)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                F.perfInvalidateLobby()
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    F.cleanArmoryPollution()
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        F.hookGarageTheme()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
-- 𝗗𝘂𝗺𝗽.𝗯𝘆.𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
end



function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookEquipmentRectify()
    F.hookWeaponSpawn()
    F.hookEnterGame()

-- ==============================================================================
-- [THÊM MỚI] LOGIC KILL MESSENGER, DEADBOX, BỘ ĐẾM KILL & ICON TỪ CODE MẪU
-- ==============================================================================
local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end
-- Ｄｕｍｐ 𝓫𝔂 ᏚᏲᎪᎠᎾᏔ shadow_cheatss

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    -- Tối ưu: Chỉ lấy tên 1 lần duy nhất, tránh gọi C++ SLUA hàng ngàn lần
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    -- [ĐÃ FIX] Lấy chính xác Skin ID của cây súng ĐANG CẦM TRÊN TAY để tránh hiện nhầm Kill Message
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            -- Chỉ xuất Kill Message nếu súng trên tay thực sự là súng VIP (ID > 1000000)
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

-- 𝕯𝖚𝖒𝖕_𝖇𝖞_𝕾𝖍𝖆𝖉𝖔𝖜_𝕾𝕳𝕯 SHD_CHT
local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    -- Tối ưu: Chỉ tải 1 lần duy nhất mỗi skin, tránh spam băng thông và CPU
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not _G.LexusConfig.KillMessage then return messageData end -- [CHẶN NẾU TẮT CÔNG TẮC]
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝓣𝓖 shadow_cheatss
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            -- [TỐI ƯU TUYỆT ĐỐI] Nếu tắt Kill Message -> Bỏ qua toàn bộ logic bên dưới, trả về nguyên bản của game luôn.
            if not _G.LexusConfig.KillMessage then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end

-- Khởi tạo hệ thống Kill Count
_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile()
    -- Đã làm rỗng hàm lưu file để chống Drop FPS
end

function _G.loadKillCountFromFile()
    -- Đã làm rỗng hàm đọc file để chống Drop FPS
end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end

-- Hook Deadbox (Tạo Hòm Xác) và KillInfo
pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            -- [TỐI ƯU TUYỆT ĐỐI] Tắt cả 3 chức năng -> Trả về game gốc ngay lập tức, siêu nhẹ
-- Dump by Shadow TG SHD_CHT
            if not _G.LexusConfig.SkinDeadBox and not _G.LexusConfig.KillCountUI and not _G.LexusConfig.KillMessage then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if _G.LexusConfig.SkinDeadBox or _G.LexusConfig.KillMessage then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI ÉP SKIN LÊN KILL FEED
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                -- [TỐI ƯU FPS] Súng Mod luôn có ID lớn hơn 1.000.000 (Ví dụ M4 Băng: 1101004046)
                                if SkinID > 1000000 then 
                                    if _G.LexusConfig.KillCountUI then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
-- 𝗗𝘂𝗺𝗽 𝗯𝘆 𝗦𝗵𝗮𝗱𝗼𝘄 𝗧𝗚 𝗦𝗛𝗗_𝗖𝗛𝗧
                                    if _G.LexusConfig.SkinDeadBox then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or _G.LexusConfig.KillMessage then
                                _G.UpdateMyKillCounter = true
                                if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI THAY ĐỔI GÓI TIN ĐỂ HIỆN TRÊN TOP
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)

-- Hook UI Kill Counter (Cập nhật số đếm & Icon trên màn hình)
pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
-- 𝐷𝑢𝑚𝑝 𝑏𝑦 𝑆ℎ𝑎𝑑𝑜𝑤 𝑇𝐺 𝑆𝐻𝐷_𝐶𝐻𝑇
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return _G.LexusConfig.KillCountUI end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            -- [TỐI ƯU TUYỆT ĐỐI] Bóp nghẹt ngay lệnh gọi UI của Game nếu đang tắt, CHỐNG CHỚP (FLASH)
            if not _G.LexusConfig.KillCountUI then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID) -- Ép tham số False
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                -- [TỐI ƯU FPS] NHẬN DIỆN SÚNG MOD: Súng thường ID < 1.000.000, Súng Mod ID > 1.000.000
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                -- Đóng UI nếu là súng lục, dao, CHẢO hoặc SÚNG THƯỜNG KHÔNG CÓ SKIN
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    -- Hiện UI nếu là súng Mod (Dù curEquipedKillCounter có trả về nil do server không nhận diện được)
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
-- Ｄｕｍｐ ｂｙ Ｓｈａｄｏｗ ＴＧ ＳＨＤ_ＣＨＴ
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)

-- Vòng lặp Updater (Đã tối ưu Cache: Chỉ Update UI khi đổi súng hoặc có mạng Kill)
local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    local UIManager = require("client.slua_ui_framework.manager")
    
    if not _G.LexusConfig.KillCountUI then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        -- Lấy DefineID an toàn, không tạo rác RAM
        local defineIDObj = currweapon:GetItemDefineID()
-- 𝓓𝓾𝓶𝓹 𝓫𝔂 𝓢𝓱𝓪𝓭𝓸𝔀 𝓣𝓖 𝓢𝓗𝓓_𝓒𝓗𝓣
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        -- Lấy Skin ID từ Cache của hệ thống Skin V7.5 (Cực nhẹ, không gọi SLUA)
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        -- TỐI ƯU CỰC ĐỘ: Chỉ gửi lệnh cập nhật UI nếu MỚI ĐỔI SÚNG hoặc MỚI GIẾT NGƯỜI
        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
    -- ĐÃ XÓA LOGIC QUÉT FILE translateec.conf LIÊN TỤC GÂY LAG
end

-- Kích hoạt Hooks và Loop
pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup() -- Chỉ gọi đọc file 1 lần duy nhất khi vào game, không lặp lại nữa
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
        -- ĐÃ XÓA VÒNG LẶP ĐỌC FILE 0.4 GIÂY ĐỂ TRÁNH DROP FPS
    end
end)
-- ==============================================================================

    if _G.LexusConfig and _G.LexusConfig.ModSkin == true then
        F.startVehicleSkinTicker()
    end
-- 𝔇𝔲𝔪𝔭 𝔟𝔶 𝔖𝔥𝔞𝔡𝔬𝔴 𝔗𝔊 𝔖ℌ𝔇_ℭℌ𝔗
    if _G.LexusConfig and _G.LexusConfig.ModSkin == true and not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end

_G.AddOutfit = F
if _G.LexusConfig and _G.LexusConfig.ModSkin == true then
    F.start()
end

-- [FIX VIP] HỆ THỐNG TỰ ĐỘNG KHÔI PHỤC SKIN Ở SẢNH KHI VỪA MỞ GAME
_G.AddOutfitLobbyRestored = false

local function AutoRestoreLobbySkin()
    if not (_G.LexusConfig and _G.LexusConfig.ModSkin == true) then return end
    if _G.AddOutfitLobbyRestored then return end
    
    -- [CỜ NGỦ ĐÔNG LOBBY]: Nếu đã leo lên máy bay vào trận -> Ngủ luôn, không đọc file Sảnh nữa!
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
-- 𝙳𝚞𝚖𝚙 𝚋𝚢 𝚂𝚑𝚊𝚍𝚘𝘸 𝚃𝙶 𝚂𝙷𝙳_𝙲𝙷𝚃
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            -- Chờ DataMgr tải xong UID của nhân vật (Tránh lỗi load sớm quá bị tịt)
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        -- Bắn liên hoàn lệnh: Đọc File -> Gán Data -> Vẽ lên nhân vật
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        -- Chốt cờ đã hoàn thành
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end

-- Chạy ngầm 1 giây / lần lúc vừa vô game, load xong là tự động ngưng
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, AutoRestoreLobbySkin, -1, 1.0)
    end
end)
-- ==============================================================================
-- ================= KẾT THÚC CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) ==============
-- ==============================================================================

-- ==============================================================================
-- ================= KẾT THÚC CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) ==============
-- ==============================================================================

-- ==============================================================================

end -- original skin module
pcall(_G.__FAHADInstallSkinCore)

-- [VIPGROUP  MERGE] Original Skin-category emote toggle backend.
-- ================= BẮT ĐẦU LOGIC MOD EMOTE (CHỈ INGAME - 0% DROP FPS) =========
-- ==============================================================================
pcall(function()
    local QuickExpressionUtils = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")

    -- Danh sách ID Hành Động VIP
    local EXTRA_EMOTES = {
          -- [ HÀNH ĐỘNG ]
    12201301, -- Hành động Sát thủ Gothic
    12216101, -- Hành động Võ sĩ Huyết Ưng
    12212201, -- Hành động Sát thủ Cực Ám
    12219207, -- Hành động Đại tướng Thiên Ngưu
    12209001, -- Hành động Võ sĩ (Samurai)
-- 𝖣𝗎𝗆𝗉 𝖻𝗒 𝲲𝗁𝖺𝖽𝗈𝗐 𝳀𝖳𝖦 𝖲𝖧𝖣_𝖢𝖧𝖳
    12219561, -- Hành động Áo choàng Đỏ thẫm
    12210001, -- Hành động Cái chạm của Tử thần
    12219022, -- Hành động Thiết vệ Gai góc
    12208801, -- Hành động Dũng sĩ Bán thần
    12210801, -- Hành động Thợ săn Vỏ bạc
    12200701, -- Hành động Du hành Không thời gian
    12219242, -- Hành động Dạo bước Bầu trời
    12206001, -- Hành động Hoa linh Đồng xanh
    12205401, -- Hành động Vua của muôn thú
    12205201, -- Hành động Trái tim Cự thú
    12212601, -- Hành động Sát lục Thần bí
    12205601, -- Hành động Linh hồn Cự thú
    12219208, -- Hành động Hầu vương Cyber
    12212001, -- Hành động Võ thánh
    12206801, -- Hành động Hải long Thần bí
    12209801, -- Hành động Ngự linh sư
    12211401, -- Hành động Nữ phù thủy Băng tuyết
    12207001, -- Hành động Du hành Biển sao
    12211801, -- Hành động Chúa tể Trật tự
    12207901, -- Hành động Hải vương Quyến rũ
    12203401, -- Hành động Kỷ niệm Ảo ảnh
    12204001, -- Hành động Chú hề (Ngày Cá tháng Tư)
    12201801, -- Hành động Người bảo vệ Vùng tuyết
    12215601, -- Hành động Siêu nhân Hằng tinh
    12215532, -- Hành động Lãnh chúa Ngọn lửa
    12213201, -- Hành động Kế hoạch Ngày mai
    12215529, -- Hành động Kỵ sĩ Đua xe
    12219053, -- Hành động Nữ hoàng Trân bảo
    12204601, -- Hành động Thiên hạ Bố võ
    12215701, -- Hành động Hành tinh Vượn người
    12219003, -- Hành động Bóng tối Thần linh
    12219004, -- Hành động Ngân hồn Rực lửa
    12219009, -- Hành động Mê hoặc Rực lửa
    12219216, -- Hành động Tế tư Héo úa
    }

    -- TỐI ƯU CỰC ĐỘ: Cache dữ liệu trên RAM để game không phải tạo bảng mới mỗi lần bấm nút
    local CachedInGameEmotes = nil
    local LastBaseCount = -1
    local LastEmoteSwitchState = nil

    -- Hàm trộn Emote 1 lần duy nhất
    local function GetOptimizedEmoteList(baseList)
        local baseCount = baseList and #baseList or 0
        local isEmoteModEnabled = _G.LexusConfig.ModEmote == true

        -- Nếu đã trộn rồi, số lượng Emote gốc không đổi, VÀ trạng thái nút Bật/Tắt không đổi -> Lấy luôn từ Cache ra xài
        if CachedInGameEmotes and LastBaseCount == baseCount and LastEmoteSwitchState == isEmoteModEnabled then
            return CachedInGameEmotes
        end
-- 𝕯𝖚𝖒𝖕 𝕾𝖍𝖆𝖉𝖔𝖜 𝕿𝕾 𝕾𝖍𝖉_𝕮𝖍𝕿

        local compact = {}
        local seen = {}
        
        -- 1. Thêm Emote mặc định của người chơi
        if baseList then
            for _, data in pairs(baseList) do
                if data and data.DefineID and data.DefineID.TypeSpecificID then
                    table.insert(compact, data)
                    seen[data.DefineID.TypeSpecificID] = true
                end
            end
        end

        -- 2. CHỈ Thêm Emote VIP NẾU ĐANG BẬT CÔNG TẮC
        if isEmoteModEnabled then
            for _, SHADOWteID in ipairs(EXTRA_EMOTES) do
                if not seen[SHADOWteID] then
                    table.insert(compact, {
                        DefineID = {TypeSpecificID = SHADOWteID},
                        Name = tostring(SHADOWteID)
                    })
                    seen[SHADOWteID] = true
                end
            end
        end

        CachedInGameEmotes = compact
        LastBaseCount = baseCount
        LastEmoteSwitchState = isEmoteModEnabled
        return CachedInGameEmotes
    end

    -- Hook vào hàm Load danh sách của In-game
    if QuickExpressionUtils and not _G.__EMOTE_INGAME_HOOKED then
        _G.__EMOTE_INGAME_HOOKED = true
        _G.__EMOTE_ORIG_GET_LIST = QuickExpressionUtils.GetShowExpressionList
        
        QuickExpressionUtils.GetShowExpressionList = function()
            local baseList, nWeaponShowEmoteID = _G.__EMOTE_ORIG_GET_LIST()
            return GetOptimizedEmoteList(baseList), nWeaponShowEmoteID
        end
    end

    -- Hook vào sự kiện bấm nút Emote trong game để ép UI vẽ ra
    if not _G.__EMOTE_MENU_EVENT_HOOKED and EventSystem and EventSystem.registEvent then
        _G.__EMOTE_MENU_EVENT_HOOKED = true
        EventSystem:registEvent(EVENTTYPE_INGAME, EVENTID_INGAME_QUICK_EXPRESSION_DECAL_CLICK, function()
            pcall(function()
                -- NẾU ĐANG TẮT MOD EMOTE -> Trả về giao diện mặc định của Game để khỏi lỗi UI
-- Ⓓⓤⓜⓟ Ⓢⓗⓐⓓⓞⓦ ⓉⒼ ⓈⒽⒹ_ⒸⒽ⓫
                if not _G.LexusConfig.ModEmote then return end 

                local UIManager = require("client.slua_ui_framework.manager")
                if not UIManager or not UIManager.UI_Config_InGame then return end
                local subPanel = UIManager.GetUI(UIManager.UI_Config_InGame.QuickExpressionDecalSubPanel)
                
                if subPanel and subPanel.GetQuickExpressionDecalItemByIndex and CachedInGameEmotes then
                    local showCount = 0
                    for _, data in ipairs(CachedInGameEmotes) do
                        local SHADOWteID = data.DefineID and data.DefineID.TypeSpecificID
                        if SHADOWteID and SHADOWteID > 0 then
                            showCount = showCount + 1
                            local item = subPanel:GetQuickExpressionDecalItemByIndex(showCount)
                            if item then
                                -- Tắt các hiệu ứng thừa làm nặng máy
                                if item.UIRoot.WidgetSwitcher_Effect then item.UIRoot.WidgetSwitcher_Effect:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                if item.UIRoot.Image_Weapon then item.UIRoot.Image_Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                
                                item:Show()
                                item:RefreshData(SHADOWteID, -1)
                            end
                        end
                    end
                    if subPanel.HideRestBlocks then subPanel:HideRestBlocks(showCount) end
                    if subPanel.UIRoot then
                        subPanel.UIRoot.WrapBox_List:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
                        subPanel.UIRoot.VerticalBox_Empty:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end)
    end
end)
-- ==============================================================================
-- ================= KẾT THÚC LOGIC MOD EMOTE ===================================
-- ==============================================================================

-- ============================================================


-- [VIPGROUP  MERGE] Single slow wardrobe match refresher, gated on license and Skin ON.
do
  local ok,ticker=pcall(require,"common.time_ticker")
  if ok and ticker and type(ticker.AddTimerLoop)=="function" then
    local marker={}
    _G.__FAHAD_SkinRefreshToken=marker
    ticker.AddTimerLoop(0,function()
      if _G.__FAHAD_SkinRefreshToken~=marker then return end
      if _G.LicenseValid~=true or not (_G.LexusConfig and _G.LexusConfig.ModSkin) then return end
      local F=_G.AddOutfit
      if not F then return end
      pcall(function()
        local player=GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if F.isInRealMatch and F.isInRealMatch() then
          if player and slua.isValid(player) then
            if F.matchApplyAllSlots then F.matchApplyAllSlots(player) end
            if F.matchApplyHat then F.matchApplyHat(player) end
            if F.matchApplyWeaponSkin then F.matchApplyWeaponSkin(player) end
          end
        elseif F.reapplyLobbyEquipped then
          F.reapplyLobbyEquipped()
        end
      end)
    end,-1,2.5)
  end
end


-- ============================================================================
-- ORIGINAL VIPGROUP  OFFLINE EXPIRY (editable date below)
-- Change only EXPIRY_TIMESTAMP's year/month/day/hour/min/sec values.
-- ============================================================================
-- ============================================================================
-- ⚡ EXPIRY SYSTEM (FIXED)
-- ========================================================================
local EXPIRY_TIMESTAMP = os.time({ year = 2027, month = 11, day = 20, hour = 12, min = 0, sec = 0 })

local function FormatTimeRemaining(sec)
    if sec <= 0 then return "0d 0h 0m 0s" end
    local days = math.floor(sec / 86400); sec = sec % 86400
    local hours = math.floor(sec / 3600); sec = sec % 3600
    local minutes = math.floor(sec / 60)
    local seconds = sec % 60
    return string.format("%dd %dh %dm %ds", days, hours, minutes, seconds)
end

function CheckExpiration()
    local now = os.time()
    local remaining = EXPIRY_TIMESTAMP - now
    if remaining <= 0 then
        _G._MOD_EXPIRED = true
        _G.LicenseValid = false
        _G._MOD_REMAINING_SECONDS = 0
        return false
    end
    _G._MOD_EXPIRED = false
    _G.LicenseValid = true
    _G._MOD_REMAINING_SECONDS = remaining
    return true
end

local function ShowExpiryPopup(expired)
    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end
        local function onClick() end
        local stamp = os.date("!%d %b %Y  |  %H:%M UTC", EXPIRY_TIMESTAMP)
        local header = "✦ VIP PAID GUROP /    ✦\n╔══════════════════════════╗\n   FEED BACK LAZMI DEYA KARY     \n╚══════════════════════════╝"
        if expired then
            local body = header .. "\n\n▰ ACCESS GATE  /  LOCKED\n\nSTATUS       :  EXPIRED\nVALIDITY     :  ENDED\nRECORD       :  " .. stamp .. "\n\nYour access period has ended.\nContact the official support channel\nfor renewal information.\n\n┏━━ SUPPORT CHANNEL ━━┓\n   @PRIME\n┗━━━━━━━━━━━━━━━━━━━━━┛\n\nPRIME  •  ACCESS CONTROL"
            Msg.Show(4, "✦   VIPGROUP   |  ACCESS LOCKED", body, onClick)
        else
            local remaining = _G._MOD_REMAINING_SECONDS or (EXPIRY_TIMESTAMP - os.time())
            local formatted = FormatTimeRemaining(remaining)
            local body = header .. "\n\n▰ ACCESS GATE  /  VERIFIED\n\nSTATUS       :  ACTIVE\nTIME LEFT    :  " .. formatted .. "\nVALID UNTIL  :  " .. stamp .. "\n\nAll interface modules are initialized.\nChoose ENTER to open the control suite.\n\n┏━━ OFFICIAL SUPPORT ━━┓\n   @PRIME\n┗━━━━━━━━━━━━━━━━━━━━━┛\n\nPRIME  •  SECURE SESSION"
            Msg.Show(4, "✦   VIPGROUP   |  LIVE ACCESS", body, onClick)
        end
    end)
end

function _G.TryShowWelcome()
    if _G.WelcomeShown then return end
    if not CheckExpiration() then
        ShowExpiryPopup(true)
        return
    end
    ShowExpiryPopup(false)
    _G.WelcomeShown = true
end

--  PRIME POPUPS: welcome sequence + field notice.
function ShowLexusVIPMenu()
    if _G.LexusMenuAlreadyShown then return end
    if not _G.LexusState or _G.LexusState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_FieldNotice()
            Msg.Show(1, "✦  PRIME  |  FIELD BRIEF", "✦  PRIME  /   VIPGROUP \n╔══════════════════════════╗\n        PILOT BRIEFING\n╚══════════════════════════╝\n\n01  /  PLAY RESPONSIBLY\n02  /  PROTECT YOUR ACCOUNT\n03  /  USE OFFICIAL SUPPORT\n\n┏━━ OFFICIAL CHANNEL ━━┓\n   @PRIME\n┗━━━━━━━━━━━━━━━━━━━━━┛\n\nPRIME  •  BRIEF 01",
                function()
                    local ok, Web = pcall(require, "client.slua.logic.url.logic_webview_sdk")
                    if ok and Web and Web.OpenURL then Web:OpenURL("PRIME") end
                end,
                function() end,
                "SUPPORT", "CLOSE")
            _G.LexusState.MenuStep = 99
            _G.LexusMenuAlreadyShown = true
        end

        local function Step_Welcome()
            Msg.Show(1, "✦  PRIME  |  VIPGROUP  ACCESS", "╔══════════════════════════╗\n       VIPGROUP  BHAIE\n╚══════════════════════════╝\n\n✦  ACCESS GRANTED\n\nEDITION      :   VIPGROUP \nINTERFACE    :  READY\nMODULES      :  INITIALIZED\n\nYour control suite is ready.\nPress ENTER to continue.\n\n┏━━ OFFICIAL SUPPORT ━━┓\n   @PRIME\n┗━━━━━━━━━━━━━━━━━━━━━┛\n\nPRIME  •   PREMIUM BUILD",
                function()
                    if _G.InitModMenuTab then _G.InitModMenuTab() end
                    if Notify then Notify("PRIME   •  PRIME READY") end
                    Step_FieldNotice()
                end,
                function() end,
                "ENTER", "CLOSE")
        end

        _G.LexusState.MenuStep = 1
        Step_Welcome()
    end)
end

-- Fire expiry/welcome popup 4 seconds after load (same as Z3ROX.lua)
pcall(function()
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        tk.AddTimerOnce(3, function() pcall(CheckExpiration) end)
        tk.AddTimerOnce(4, function()
            if not CheckExpiration() then pcall(ShowExpiryPopup, true)
            else pcall(_G.TryShowWelcome) end
        end)
    else
        pcall(_G.TryShowWelcome)
    end
end)


-- Initialize local access status before gameplay hooks are enabled.
CheckExpiration()
-- Keep offline expiry current even if the ESP menu is never opened.
-- One lightweight clock check per 5 seconds; old timers and gameplay code are unchanged.
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and type(ticker.AddTimerLoop) == "function" then
        local token = {}
        _G.__FAHAD_OfflineExpiryTicker = token
        ticker.AddTimerLoop(0, function()
            if _G.__FAHAD_OfflineExpiryTicker ~= token then return end
            CheckExpiration()
        end, -1, 5.0)
    end
end)

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  },
  -- Existing additional game feature retained from the main script.
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
}, "BRPlayerCharacterBase")
-- ORIGINAL GAME CLASS AND FEATURE REGISTRATION END
