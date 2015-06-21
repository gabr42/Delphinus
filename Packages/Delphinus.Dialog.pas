unit Delphinus.Dialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  DN.PackageOverview, System.Actions, Vcl.ActnList, Vcl.ImgList, Vcl.ToolWin,
  Vcl.ComCtrls,
  DN.PackageProvider.Intf,
  DN.Package.Intf,
  Generics.Collections,
  Delphinus.PackageDetailView;

type
  TDelphinusDialog = class(TForm)
    ToolBar1: TToolBar;
    imgMenu: TImageList;
    DialogActions: TActionList;
    ToolButton1: TToolButton;
    actRefresh: TAction;
    procedure actRefreshExecute(Sender: TObject);
  private
    { Private declarations }
    FOverView: TPackageOverView;
    FDetailView: TPackageDetailView;
    FPackageProvider: IDNPackageProvider;
    FInstalledPackageProvider: IDNPackageProvider;
    FPackages: TList<IDNPackage>;
    FInstalledPackages: TList<IDNPackage>;
    procedure HandleSelectedPackageChanged(Sender: TObject);
    procedure HandleInstallPackage(Sender: TObject);
    procedure HandleUninstallPackage(Sender: TObject);
    function GetComponentDirectory: string;
    function GetBPLDirectory: string;
    function GetDCPDirectory: string;
    procedure RefreshInstalledPackages;
    function IsPackageInstalled(const APackage: IDNPackage): Boolean;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
  end;

var
  DelphinusDialog: TDelphinusDialog;

implementation

uses
  IOUtils,
  DN.PackageProvider.GitHub,
  DN.PackageProvider.Installed,
  Delphinus.SetupDialog,
  DN.Compiler.Intf,
  DN.Compiler.MSBuild,
  DN.Installer.Intf,
  DN.Installer,
  DN.Uninstaller.Intf,
  DN.Uninstaller;

{$R *.dfm}

{ TDelphinusDialog }

procedure TDelphinusDialog.actRefreshExecute(Sender: TObject);
begin
  FPackages.Clear;
  if FPackageProvider.Reload() then
  begin
    FPackages.AddRange(FPackageProvider.Packages);
    FOverView.Clear;
    FOverView.Packages.AddRange(FPackages);
  end;
  RefreshInstalledPackages();
end;

constructor TDelphinusDialog.Create(AOwner: TComponent);
begin
  inherited;
  FOverView := TPackageOverView.Create(Self);
  FOverView.Align := alClient;
  FOverView.Parent := Self;
  FOverView.OnSelectedPackageChanged := HandleSelectedPackageChanged;
  FOverView.BorderStyle := bsSingle;
  FDetailView := TPackageDetailView.Create(Self);
  FDetailView.Align := alRight;
  FDetailView.AlignWithMargins := True;
  FDetailView.btnInstall.OnClick := HandleInstallPackage;
  FDetailView.btnUninstall.OnClick := HandleUninstallPackage;
  FDetailView.Parent := Self;
  FPackages := TList<IDNPackage>.Create();
  FInstalledPackages := TList<IDNPackage>.Create();
  FPackageProvider := TDNGitHubPackageProvider.Create();
  FInstalledPackageProvider := TDNInstalledPackageProvider.Create(GetComponentDirectory());
end;

destructor TDelphinusDialog.Destroy;
begin
  FOverView.OnSelectedPackageChanged := nil;
  FPackages.Free;
  FInstalledPackages.Free;
  FPackageProvider := nil;
  FInstalledPackageProvider := nil;
  inherited;
end;

function TDelphinusDialog.GetBPLDirectory: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('BDSCOMMONDIR'), 'Bpl');
end;

function TDelphinusDialog.GetComponentDirectory: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('BDSCOMMONDIR'), 'Comps');
end;

function TDelphinusDialog.GetDCPDirectory: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('BDSCOMMONDIR'), 'Dcp');
end;

procedure TDelphinusDialog.HandleInstallPackage(Sender: TObject);
var
  LDialog: TSetupDialog;
  LCompiler: IDNCompiler;
  LInstaller: IDNInstaller;
begin
  if Assigned(FOverView.SelectedPackage) then
  begin
    LDialog := TSetupDialog.Create(nil);
    try
      LCompiler := TDNMSBuildCompiler.Create(GetEnvironmentVariable('BDSBIN'));
      LCompiler.BPLOutput := GetBPLDirectory();
      LCompiler.DCPOutput := GetDCPDirectory();
      LInstaller := TDNInstaller.Create(LCompiler, Trunc(CompilerVersion));
      LDialog.ExecuteInstallation(FOverView.SelectedPackage, FPackageProvider, LInstaller,
        GetComponentDirectory());
    finally
      LDialog.Free;
    end;
    RefreshInstalledPackages();
  end;
end;

procedure TDelphinusDialog.HandleSelectedPackageChanged(Sender: TObject);
begin
  FDetailView.Package := FOverView.SelectedPackage;
  FDetailView.btnUninstall.Enabled := IsPackageInstalled(FOverView.SelectedPackage);
  FDetailView.btnInstall.Enabled := not FDetailView.btnUninstall.Enabled;
end;

procedure TDelphinusDialog.HandleUninstallPackage(Sender: TObject);
var
  LDialog: TSetupDialog;
  LUninstaller: IDNUninstaller;
begin
  if Assigned(FOverView.SelectedPackage) then
  begin
    LDialog := TSetupDialog.Create(nil);
    try
      LUninstaller := TDNUnInstaller.Create();
      LDialog.ExecuteUninstallation(TPath.Combine(GetComponentDirectory(), FOverview.SelectedPackage.Name), LUninstaller);
    finally
      LDialog.Free;
    end;
    RefreshInstalledPackages();
  end;
end;

function TDelphinusDialog.IsPackageInstalled(
  const APackage: IDNPackage): Boolean;
var
  LPackage: IDNPackage;
begin
  Result := False;
  if Assigned(APackage) then
  begin
    for LPackage in FInstalledPackages do
    begin
      if LPackage.Name = APackage.Name then
        Exit(True);
    end;
  end;
end;

procedure TDelphinusDialog.RefreshInstalledPackages;
begin
  if FInstalledPackageProvider.Reload() then
  begin
    FInstalledPackages.Clear;
    FInstalledPackages.AddRange(FInstalledPackageProvider.Packages);
    HandleSelectedPackageChanged(FDetailView);
  end;
end;

end.