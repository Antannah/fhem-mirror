########################################################################################
#
# SONOS.pm (c) by Reiner Leins, 2014
# rleins at lmsoft dot de
#
# $Id$
#
# FHEM module to commmunicate with a Sonos-System via UPnP
#
# !WARNING!
# This Module needs UPnP-Library
# Installation:
#  * LWP::Simple
#  * HTML::Entities
#  * Net::Ping
#  * File::Path
#  * Time::HiRes
#  * threads
#  * Thread::Queue
#
# Internal Version 2.6 - December, 2014
#
# define <name> SONOS <host:port> [[[interval] waittime] delaytime]
#
# where <name> may be replaced by any name string 
# <host:port> is the connection identifier to the internal server. Normally "localhost" with a locally free port e.g. "localhost:4711".
# interval is the interval in s, for checking the existence of a ZonePlayer after definition
# waittime is the time to wait for the subprocess. defaults to 8.
# delaytime is the Time for delaying the network- and subprocess-part of this module. If the port is longer than neccessary blocked on the subprocess-side, it may be useful.
#
########################################################################################
# Changelog
#
# SVN-History:
# 26.12.2014:
#	DeleteFn für Sonos wurde implementiert. Das Sonos-Device löscht erst alle SonosPlayer-Devices und beendet den selbst gestarteten SubProzess. Danach wird das Sonos-Device selber von Fhem abgeräumt.
#	DeleteFn für SonosPlayer wurde implementiert. Es werden erst alle automatisch erzeugten Devices (RemoteControl und ReadingsGroups) entfernt, sofern sie noch unter dem Originalnamen existieren.
#	ReportUnresponsiveDevice hat manchmal versucht, die Mitteilung an "sich selbst" zu senden, was naturgemäß nicht klappen kann.
#
# 2.6:	Die Zeichenkodierung bei Datenübernahme vom Zoneplayer kann nun über das Attribut characterDecoding eingestellt werden
#		Bei Gruppen-/LineIn-/SPDIF-Wiedergabe wird wieder die liefernde Zone angezeigt (als Albumname)
#		SetCurrentPlaylist hatte einen Tippfehler, und konnte dementsprechend nicht ausgeführt werden
#		Unter Ubuntu gibt es die SHA1-Library nicht mehr, sodass man dort eine andere einbinden muss (SHA)
#		Wenn bei den Methoden zum heraussuchen der FHEM-Devices etwas nicht gefunden wurde, dann wird jetzt eine Fehlermeldung mit dem gesuchten Merkmal ausgegeben
#		Es können jetzt IP-Adressen von der UPnP-Verarbeitung ausgeschlossen werden
#		Es wird nun ein fester Mimetype 'jpg' für Google Music und Simfy festgelegt
#		Beim Alarm-Reading-Setzen wurde etwas doppelt gesetzt, was u.U. zu Fehlern führen konnte
#		Die Read-Function wurde robuster gegen Übertragungsprobleme gemacht
#		Das Wiederherstellen des Playerzustands nach einem PlayURITemp sieht nun auch den PlayBar-Eingang vor
#		Es wird nun anstatt der WebCmd-Auflistung ein RemoteControl beim Erstellen der Komponenten erzeugt
#		Wenn sich doch noch ein UPnP-Device als Player ausgibt, dann wird dies nun etwas sicherer erkannt
#		Der Eingang einer Playbar kann nun auf anderen Playern wiedergegeben werden (mittels des Fhem-Namens)
#		Lesen wurde auf DevIo_SimpleRead umgestellt (stand auf DevIo_DoSimpleRead). Dadurch wird das Fehlerhandling vereinfacht.
#		Man kann die Zeit für das Warten auf den Subprozess nun beim Define mit angeben. Standardmäßig wird 8 verwendet.
#		Es wird nun in regelmäßigen Abständen (Intervall wie bei der Prüfung der Sonosplayer) geprüft, ob die Verbindung zum Subprozess noch funktioniert
#		Die Readings, die beim Start nicht geladen werden dürfen, werden beim Start von Fhem nun initialisiert. Damit wird die Fehlermeldung in MOTD verhindert
#		Der Zeitstempel in der Konsolenausgabe berücksichtigt nun auch die Global-Angabe, ob Millisekunden mit ausgegeben werden sollen
#		Der Start wurde komplett überarbeitet. Nun sind die einzelnen Wartebereiche in Timer ausgelagert, sodass Fhem nicht mit warten blockiert wird.
#		Die Wiederherstellung des alten Playerzustands nach einem PlayURITemp (und damit auch bei Speak) wird nun auch bei Dateien gemacht, die mit 0s Dauer ermittelt werden (da sie sehr kurz sind).
#		Der Aufruf der Google Text2Speech-Engine wird nun bei mehr als 95 Zeichen in mehrere Aufrufe aufgeteilt. Damit sind nun auch lange Texte über Google möglich, allerdings geht die Textmelodie u.U. verloren.
#		Man kann jetzt für die Speak-Erzeugung ein JPG- oder PNG-Bild angeben. Dies kann für jedes Speak-Programm getrennt erfolgen.
#		Beim Speak-Aufruf werden Umlaute nun auch korrekt an den Text2Speech-Generator (z.B. Google) übergeben, und korrekt in den MP3-Tag geschrieben
#		Spotify-Cover werden nun in größerer Auflösung (meist 640x640 Pixel) direkt von Spotify heruntergeladen, und enthalten dann nicht mehr das Spotify-Logo
#		Es gibt zwei neue Readings 'currentAlbumArtURL' und 'nextAlbumArtURL', die die Originalpfade zum eigenen Download darstellen
#		Es gibt nun zwei Prozeduren, die als Grundlage oder Beispiel für die Verwendung von ReadingsGroups dienen können: 'SONOS_getTitleRG' und 'SONOS_getCoverRG'
#		Beim automatischen Erzeugen der Sonos-Devices werden nun ReadingsGroups mit mehr Informationen erzeugt. Dies kann (und soll) auch als Vorlage für eigene Ideen Verwendet werden
#		Es gibt eine weitere ReadingsGroup-Vorlage (steht auch im Wiki), mit der Listen (Playlisten, Favoriten und Radios) dargestellt werden können
#		Es gibt zwei neue Attribute "proxyCacheTime" und "proxyCacheDir", die einen Cache im Proxy aktivieren
#		Es gibt drei neue Getter am Sonosplayer-Device: "FavouritesWithCover", "PlaylistsWithCover" und "RadiosWithCovers". Diese geben eine Datenstruktur zurück, die den Titel und das Cover des Elements enthält.
#		Die Prozeduren für die Anzeige des aktuellen und nächsten Titels verwenden nun ausschließlich DIV-Container (anstatt Tabellen). Dadurch klappt die Anzeige auch in einem Dashboard.
#		Die Standard-ReadingsGroup-Anzeige durch die Prozeduren sind nun Parametrisiert. Man kann die minimale Breite der Anzeige sowie den Abstand zwischen aktuellem und nächstem Titel in Pixel festlegen
#		Manche Sender (z.B. Capital Radio Türkiye) haben verbotene Newlines in den Titelinformationen mitgesendet. Diese werden nun entfernt.
#		Man kann das Cover nun anklicken (oder antippen), und erhält dann die Coverdarstellung in einer Vollbilddarstellung mit Abspielstatus und Titelinformationen
#		Es gibt zwei neue Befehle 'StartPlaylist' und 'StartRadio', die die gleichen Parameter wie ihre Pendants mit 'Load' am Anfang haben, nur dass hier das Abspielen gleich gestartet wird.
#		Es gibt jetzt ein Reading 'currentTrackPosition', welches bei jedem Transportstate-Wechsel (neuer Titel, Play/Pause/Stop usw.) gesetzt wird. Damit kann man die verbleibende Restzeit eines laufenden Titels ermitteln, bzw. den Pausezeitpunkt anzeigen.
#		Beim Wiedergeben von TV oder sonstigen externen Quellen, wird jetzt nicht mehr das 'leere' Cover angezeigt, sondern ein TV-Cover bzw. ein Default-Input-Cover
#		Aufnahme in das offizielle Release von Fhem
#
# 2.5:	Verwendung und Speicherung der Benutzer-IDs für Spotify und Napster wurden stabiler gegenüber Sonderzeichen gemacht
#		Spotify-URLs werden im Reading 'currentTrackURI' und 'nextTrackURI' lesbarer abgelegt
#		Ein Fehler beim Öffnen von M3U-Playlistdateien wurde behoben (dafür Danke an John)
#		Überholt: Für die Informationsanfragen an Fhem durch den SubProzess wird nun standardmäßig der Telnet-Port von Fhem verwendet. Wenn das fehlschlägt, wird auf den alten Mechanismus zurückgeschaltet
#		Neu: Es werden keine Informationsanfragen mehr zwischen Fhem und dem SubProzess ausgetauscht. Notwendige Informationen müssen vorher übertragen werden. Das bedeutet, dass bei einer Attributänderung ein Neustart von Fhem erfolgen muss.
#		Es wurde ein Standard-Layout für das RemoteControl-Hilfsmodul angelegt
#		Der Verbose-Level des Sonos-Devices wird nun auch an den SubProzess weitergereicht (auch zur Laufzeit), und beim initialen Start des SubProzess-Threads mitgegeben.
#		AlbumArt von Napster erhält nun den festen Mimetype 'jpg', da dieser nicht übertragen wird
#		Es werden nun die durch Fhem definierten Standard-Attribute mit angeboten
#		Es gab ein Problem mit der Befehlsverarbeitung, wenn das Verbose-Attribut an einem Sonos-Device gesetzt war.
#		Es wird nun auf Änderungsevents für den Zonennamen und das Zonenicon reagiert, und die entsprechenden Readings aktualisiert
#		Es gibt jetzt zwei neue Setter: 'Name' und 'Icon', mit dem der Name und das Icon der Zone eingestellt werden kann
#		Es gibt jetzt einen Getter 'PossibleRoomIcons', welcher die möglichen Angaben für den neuen Setter 'Icon' liefert
#		Das Reading 'ZoneGroupID' wird nun auf eine andere Weise ermittelt und gesetzt
#		Es gib jetzt ein neues Reading 'AlarmRunning', welches auf '1' steht, wenn gerade eine Alarmabspielung aktiv ist
#		Die Namens- und Aufgabenerkennung beim Ermitteln der Player wurde angepasst
#		Der Aufruf von AddMember und RemoveMember wurde bzgl. des SonosDevice-Namen abgesichert, sodass hier kein Absturz mehr bei einer falschen Deviceangabe erfolgt
#		Es gibt jetzt ein neues Reading 'AlarmRunningID', welches bei einer Alarmausführung die ID des aktiven Alarms enthält
#		Das Senden von Aktualisierungen an Fhem wurde etwas sicherer gemacht, wenn Fhem auf der anderen Seite gerade nicht zuhören kann
#		Die Readings 'AlarmList', 'AlarmListIDs' und 'AlarmListVersion' werden nicht mehr aus dem Statefile geladen, da dort Sonderzeichen wie '#' zum Abschneiden der restlichen Zeile führen
#		Anpassung der UPnP-Klasse, damit das Device-Beschreibungsdokument nur noch einmal geladen wird (anstatt wie bisher zweimal)
#		Anpassung im Bereich der Cover Aktualisierung über FhemWeb. Das geht jetzt mit viel weniger Aufwand durch.
#		Es gibt jetzt einen Setter 'SnapshotGroupVolume', der das aktuelle Lautstärkenverhältnis der einzelnen Player einer Gruppe für die folgenden Aufrufe des Setter 'GroupVolume' festhält. Die Anweisungen 'PlayURI' und 'PlayURITemp' (sowie darauf aufbauende Aufrufe wie 'Speak') führen diese Anweisung selbsttätig beim Starten durch.
#		Wenn beim Auffrischen der Subscriptions ein Fehler auftritt, der darauf schließen läßt, dass der Player weg ist, dann wird die entsprechende Referenz aufgeräumt
#		Man kann als relative Angabe bei setVolume nun einen Prozentwert angeben, z.B. '+20%'. Damit wird die Lautstärke um den jeweiligen prozentualen Anteil erhöht oder abgesenkt.
#		Es gibt jetzt ein Reading 'LineInConnected', welches eine '1' enthält, wenn der Line-In-Eingang angeschlossen wurde, sonst '0'.
#
# 2.4:	Initiale Lautstärkenermittlung wurde nun abgesichert, falls die Anfrage beim Player fehlschlägt
#		Verbesserte Gruppenerkennung für die Anzeige der Informationen wie Titel usw.
#		Fallback (Log) für den Aufruf von Log3 geschaffen, damit auch alte FHEM-Versionen funktionieren
#		Es wurde eine Korrektur im verwendetetn UPnP-Modul gemacht, die eine bessere Verarbeitung der eingehenden Datagramme gewährleistet (dafür Danke an Sacha)
#		Es werden nun zusätzliche Readings (beginnend mit 'next') mit den Informationen über den nächsten Titel befüllt. Diese können natürlich auch für InfoSummarize verwendet werden
#		Es kann nun ein Eintrag aus der Sonos-Favoritenliste gestartet werden (Playlist oder Direkteintrag)
#		Das Benennen der Sonos-Fhem-Devices wird nun auf Namensdoppelungen hin überprüft, und der Name eindeutig gemacht. Dabei wird im Normalfall das neue Reading 'fieldType' an den Namen angehangen. Nur der Master einer solchen Paarung bekommt dann den Original-Raumnamen als Fhem-Devicenamen
#		Es gibt ein neues Reading 'fieldType', mit dem man erkennen kann, an welcher Position in einer Paarung dieser Zoneplayer steht
#		Diverse Probleme mit Gruppen und Paarungen beim neu Erkennen der Sonos-Landschaft wurden beseitigt
#		Es gibt jetzt einen Getter 'EthernetPortStatus', der den Status des gewünschten Ethernet-Ports liefert
#		Es gibt jetzt einen Setter 'Reboot', der einen Neustart des Zoneplayers durchführt
#		Es gibt jetzt einen Setter 'Wifi', mit dem der Zustand des Wifi-Ports eines Zoneplayers gesetzt werden kann
#		Wenn ein Player als "Disappeared" erkannt wird, wird dem Sonos-System dies mitgeteilt, sodass er aus allen Listen und Controllern verschwindet
#		Kleinere Korrektur, die eine bessere Verarbeitung der Kommunikation zwischen Fhem und dem Subprozess bewirkt
#
# 2.3:	Die Antwort von 'SetCurrentPlaylist' wurde korrigiert. Dort kam vorher 'SetToCurrentPlaylist' zurück.
#		VolumeStep kann nun auch als Attribut definiert werden. Das fehlte in der zulässigen Liste noch.
#		Speak kann nun auch für lokale Binary-Aufrufe konfiguriert werden.
#		Speak kann nun einen Hash-Wert auf Basis des gegebenen Textes in den Dateinamen einarbeiten, und diese dann bei Gleichheit wiederverwenden (Caching)
#		Sonos kann nun ein "set StopAll" oder "set PauseAll" ausführen, um alle Player/Gruppen auf einen Schlag zu stoppen/pausieren
#		Beim Discover-Event wird nun genauer geprüft, ob sich überhaupt ein ZonePlayer gemeldet hat
#		Die UserIDs für Napster und Spotify werden wieder korrekt ermittelt. Damit kann auch wieder ein Playlistenimport erfolgen.
#		Loudness Einstell- und Abfragbar
#		Bass Einstell- und Abfragbar
#		Treble Einstell- und Abfragbar
#		Volume kann nun auch als RampToVolume ausgeführt werden
#
# 2.2:	Befehlswarteschlange wieder ausgebaut. Dadurch gibt es nur noch das Reading LastActionResult, und alles wird viel zügiger ausgeführt, da Fhem nicht auf die Ausführung warten muss.
#		TempPlaying berücksichtigt nun auch die Wiedergabe von Line-In-Eingängen (also auch Speak)
#		Veraltete, mittlerweile unbenutzte, Readings werden nun gelöscht
#		SetLEDState wurde hinzugefügt
#		Die IsAlive-Überprüfung kann mit 'none' abgeschaltet werden
#		CurrentTempPlaying wird nicht mehr benötigt
#
# 2.1:	Neuen Befehl 'CurrentPlaylist' eingeführt
#
# 2.0:	Neue Konzeptbasis eingebaut
#		Man kann Gruppen auf- und wieder abbauen
#		Es gibt neue Lautstärke- und Mute-Einstellungen für Gruppen ingesamt
#		Man kann Button-Events definieren
#
# 1.13:	Neuer Abspielzustand 'TRANSITIONING' wird berücksichtigt
#		Der Aufruf von 'GetDeviceDefHash' wird nun mit dem Parameter 'undef' anstatt ohne einen Parameter durchgeführt
#
# 1.12:	TrackURI hinzugefügt
#		LoadPlayList und SavePlayList können nun auch Dateinamen annehmen, um eine M3U-Datei zu erzeugen/als Abspielliste zu laden
#		Alarme können ausgelesen, gesetzt und gelöscht werden
#		SleepTimer kann gesetzt und ausgelesen werden
#		Reading DailyIndexRefreshTime hinzugefügt
#		Bei AddURIToQueue und PlayURI können jetzt auch (wie bei LoadPlayList) Spotify und Napster-Ressourcen angegeben werden
#		Beim Erzeugen des Cover-Weblinks wird nun nur noch die Breite festgelegt, damit Nicht-Quadratische Cover auch korrekt dargestellt werden
#		SONOS_Stringify gibt Strings nun in einfachen Anführungszeichen aus (und maskiert etwaig enthaltene im String selbst)
#
# 1.11:	Ein Transport-Event-Subscribing wird nur dann gemacht, wenn es auch einen Transport-Service gibt. Die Bridge z.B. hat sowas nicht.
#		Bei PlayURITemp wird nun der Mute-Zustand auf UnMute gesetzt, und anschließend wiederhergestellt
#		Shuffle, Repeat und CrossfadeMode können nun gesetzt und abgefragt werden. Desweiteren wird der Status beim Transport-Event aktualisiert.
#		Umlaute bei "generateInfoSmmarize3" durch "sichere" Schreibweise ersetzt (Lautst&auml;rke -> Lautstaerke)
#
# 1.10:	IsAlive beendet nicht mehr den Thread, wenn der Player nicht mehr erreichbar ist, sondern löscht nur noch die Proxy-Referenzen
#		FHEMWEB-Icons werden nur noch im Hauptthread aktualisiert
#		Getter 'getBalance' und Setter 'setBalance' eingeführt.
#		HeadphoneConnected inkl. minVolumeHeadphone und maxVolumeHeadphone eingeführt
#		InfoSummarize um die Möglichkeit der Volume/Balance/HeadphoneConnected-Felder erweitert. Außerdem werden diese Info-Felder nun auch bei einem Volume-Event neu berechnet (und triggern bei Bedarf auch!)
#		InfoSummarize-Features erweitert: 'instead' und 'emptyval' hinzugefügt
#		IsAlive prüft nicht mehr bei jedem Durchgang bis zum Thread runter, ob die Subscriptions erneuert werden müssen 
#
# 1.9:	RTL.it Informationen werden nun schöner dargestellt (Da steht eine XML-Struktur im Titel)
#		Wenn kein Cover vom Sonos geliefert werden kann, wird das FHEM-Logo als Standard verwendet (da dieses sowieso auf dem Rechner vorliegt)
#		UPnP-Fehlermeldungen eingebaut, um bei einer Nichtausführung nähere Informationen erhalten zu können
#
# 1.8:	Device-Removed wird nun sicher ausgeführt. Manchmal bekommt man wohl deviceRemoved-Events ohne ein vorheriges deviceAdded-Event. Dann gibt es die gesuchte Referenz nicht.
#		Renew-Subscriptions wurden zu spät ausgeführt. Da war alles schon abgelaufen, und konnte nicht mehr verlängert werden.
#		ZonePlayer-Icon wird nun immer beim Discover-Event heruntergeladen. Damit wird es auch wieder aktualisiert, wenn FHEM das Icon beim Update verwirft.
#		MinVolume und MaxVolume eingeführt. Damit kann nun der Lautstärkeregelbereich der ZonePlayer festgelegt werden
#		Umlaute beim Übertragen in das Reading State werden wieder korrekt übertragen. Das Problem waren die etwaigen doppelten Anführungsstriche. Diese werden nun maskiert.
#		Sonos Docks werden nun auch erkannt. Dieses hat eine andere Device-Struktur, weswegen der Erkennungsprozess angepasst werden musste.
#
# 1.7:	Umlaute werden bei Playernamen beim Anlegen des Devices korrekt umgewandelt, und nicht in Unterstriche
#		Renew-Subscription eingebaut, damit ein Player nicht die Verbindung zum Modul verliert
#		CurrentTempPlaying wird nun auch sauber beim Abbrechen des Restore-Vorgangs zurückgesetzt
#		Die Discovermechanik umgebaut, damit dieser Thread nach einem Discover nicht neu erzeugt werden muss.
#
# 1.6:	Speak hinzugefügt (siehe Doku im Wiki)
#		Korrektur von PlayURITemp für Dateien, für die Sonos keine Abspiellänge zur Verfügung stellt
#		Korrektur des Thread-Problems welches unter *Nix-Varianten auftrat (Windows war nicht betroffen)
#
# 1.5:	PlayURI, PlayURITemp und AddURIToQueue hinzugefügt (siehe Doku im Wiki)
#
# 1.4:	Exception-Handling bei der Befehlsausführung soll FHEM besser vor verschwundenen Playern schützen 
#		Variable $SONOS_ThisThreadEnded sichert die korrekte Beendigung des vorhandenen Threads, trotz Discover-Events in der Pipeline
#		Einrückungen im Code korrigiert
#
# 1.3:	StopHandling prüft nun auch, ob die Referenz noch existiert
#
# 1.2:	Proxy-Objekte werden beim Disappearen des Player entfernt, und sorgen bei einem nachfolgenden Aufruf für eine saubere Fehlermeldung
#		Probleme mit Anführungszeichen " in Liedtiteln und Artist-Angaben. Diese Zeichen werden nun ersetzt
#		Weblink wurde mit fehlendem "/" am Anfang angelegt. Dadurch hat dieser nicht im Floorplan funktionert
#		pingType wird nun auf Korrektheit geprüft.
#		Play:3 haben keinen Audio-Eingang, deshalb funktioniert das Holen eines Proxy dafür auch nicht. Jetzt ist das Holen abgesichert.
#
# 1.1: 	Ping-Methode einstellbar über Attribut 'pingType'
#
# 1.0:	Initial Release
#
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################
# Use-Declarations
########################################################################################
package main;

use strict;
use warnings;

use Cwd qw(realpath);
use LWP::Simple;
use LWP::UserAgent;
use URI::Escape;
use HTML::Entities;
use Net::Ping;
use Socket;
use IO::Select;
use IO::Socket::INET;
use File::Path;
use File::stat;
use Time::HiRes qw(usleep gettimeofday);
use Scalar::Util qw(reftype looks_like_number);
use PerlIO::encoding;
use Encode;
use Digest::MD5 qw(md5_hex);
use File::Temp;

use Data::Dumper;
$Data::Dumper::Terse = 1;

use threads;
use Thread::Queue;
use threads::shared;

use feature 'state';


########################################################
# IP-Adressen, die vom UPnP-Modul ignoriert werden sollen
########################################################
my %IgnoreIPs = ();


########################################################
# Standards aus FHEM einbinden
########################################################
use vars qw{%attr %defs %intAt %data};


########################################################
# Prozeduren für den Betrieb des Standalone-Parts
########################################################
sub Log($$);
sub Log3($$$);

sub SONOS_Log($$$);
sub SONOS_StartClientProcessIfNeccessary($);
sub SONOS_Client_Notifier($);
sub SONOS_Client_ConsumeMessage($$);

sub SONOS_RCLayout();


########################################################
# Verrenkungen um in allen Situationen das benötigte 
# Modul sauber geladen zu bekommen..
########################################################
my $gPath = '';
BEGIN {
	$gPath = substr($0, 0, rindex($0, '/'));
}
if (lc(substr($0, -7)) eq 'fhem.pl') { 
	$gPath = $attr{global}{modpath}.'/FHEM'; 
}
use lib ($gPath.'/lib', $gPath.'/FHEM/lib', './FHEM/lib', './lib', './FHEM', './');
print 'Current: "'.$0.'", gPath: "'.$gPath."\"\n";
use UPnP::ControlPoint;
require 'DevIo.pm' if (lc(substr($0, -7)) eq 'fhem.pl');


########################################################################################
# Variable Definitions
########################################################################################
my %gets = (
	'Groups' => ''
);

my %sets = (
	'Groups' => 'groupdefinitions',
	'StopAll' => '',
	'PauseAll' => ''
);

my @SONOS_PossibleDefinitions = qw(NAME INTERVAL);
my @SONOS_PossibleAttributes = qw(targetSpeakFileHashCache targetSpeakFileTimestamp targetSpeakDir targetSpeakURL Speak0 Speak1 Speak2 Speak3 Speak4 SpeakCover Speak1Cover Speak2Cover Speak3Cover Speak4Cover minVolume maxVolume minVolumeHeadphone maxVolumeHeadphone getAlarms disable generateVolumeEvent buttonEvents characterDecoding generateProxyAlbumArtURLs proxyCacheTime);
my @SONOS_PossibleReadings = qw(AlarmList AlarmListIDs UserID_Spotify UserID_Napster location SleepTimerVersion Mute HeadphoneConnected Balance Volume Loudness Bass Treble AlarmListVersion ZonePlayerUUIDsInGroup ZoneGroupID fieldType ZoneGroupName roomName roomIcon LineInConnected);

# Obsolete Einstellungen...
my $SONOS_UseTelnetForQuestions = 1;
my $SONOS_UseTelnetForQuestions_Host = 'localhost'; # Wird automatisch durch den anfragenden Host ersetzt
my $SONOS_UseTelnetForQuestions_Port = 7072;

# Communication between the two "levels" of threads
my $SONOS_ComObjectTransportQueue = Thread::Queue->new();

my %SONOS_PlayerRestoreRunningUDN :shared = ();
my $SONOS_PlayerRestoreQueue = Thread::Queue->new();

# For triggering the Main-Thread over Telnet-Session
my $SONOS_Thread :shared = -1;
my $SONOS_Thread_IsAlive :shared = -1;
my $SONOS_Thread_PlayerRestore :shared = -1;

my %SONOS_Thread_IsAlive_Counter;
my $SONOS_Thread_IsAlive_Counter_MaxMerci = 2;

# Some Constants
my @SONOS_PINGTYPELIST = qw(none tcp udp icmp syn);
my $SONOS_DEFAULTPINGTYPE = 'syn';
my $SONOS_SUBSCRIPTIONSRENEWAL = 1800; 
my $SONOS_DIDLHeader = '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">';
my $SONOS_DIDLFooter = '</DIDL-Lite>';
my $SONOS_GOOGLETRANSLATOR_CHUNKSIZE = 95;

# Basis UPnP-Object und Search-Referenzen
my $SONOS_Controlpoint;
my $SONOS_Search;

# ControlProxies für spätere Aufrufe für jeden ZonePlayer extra sichern
my %SONOS_AVTransportControlProxy;
my %SONOS_RenderingControlProxy;
my %SONOS_GroupRenderingControlProxy;
my %SONOS_ContentDirectoryControlProxy;
my %SONOS_AlarmClockControlProxy;
my %SONOS_AudioInProxy;
my %SONOS_DevicePropertiesProxy;
my %SONOS_GroupManagementProxy;
my %SONOS_MusicServicesProxy;
my %SONOS_ZoneGroupTopologyProxy;

# Subscriptions müssen für die spätere Erneuerung aufbewahrt werden
my %SONOS_TransportSubscriptions;
my %SONOS_RenderingSubscriptions;
my %SONOS_AlarmSubscriptions; 
my %SONOS_ZoneGroupTopologySubscriptions;
my %SONOS_DevicePropertiesSubscriptions;
my %SONOS_AudioInSubscriptions;

# Locations -> UDN der einzelnen Player merken, damit die Event-Verarbeitung schneller geht
my %SONOS_Locations;

# Wenn der Prozess/das Modul nicht von fhem aus gestartet wurde, dann versuchen, den ersten Parameter zu ermitteln
# Für diese Funktionalität werden einige Variablen benötigt
my $SONOS_ListenPort = $ARGV[0] if (lc(substr($0, -7)) ne 'fhem.pl');
my $SONOS_Client_LogLevel = -1;
if ($ARGV[1]) {
	$SONOS_Client_LogLevel = $ARGV[1];
}
my $SONOS_mseclog = 0;
if ($ARGV[2]) {
	$SONOS_mseclog = $ARGV[2];
}
my $SONOS_StartedOwnUPnPServer = 0;
my $SONOS_Client_Selector;
my %SONOS_Client_Data :shared = ();
my $SONOS_Client_NormalQueueWorking :shared = 1;
my $SONOS_Client_SendQueue = Thread::Queue->new();
my $SONOS_Client_SendQueue_Suspend :shared = 0;

my %SONOS_ButtonPressQueue;

########################################################################################
#
# SONOS_Initialize
#
# Parameter hash = hash of device addressed
#
########################################################################################
sub SONOS_Initialize ($) {
	my ($hash) = @_;
	# Provider
	$hash->{Clients}     = ':SONOSPLAYER:';
	
	# Normal Defines
	$hash->{DefFn}   = 'SONOS_Define';
	$hash->{UndefFn} = 'SONOS_Undef';
	$hash->{DeleteFn} = 'SONOS_Delete';
	$hash->{ShutdownFn} = 'SONOS_Shutdown';
	$hash->{ReadFn}  = "SONOS_Read";
	$hash->{ReadyFn} = "SONOS_Ready";
	$hash->{GetFn}   = 'SONOS_Get';
	$hash->{SetFn}   = 'SONOS_Set';
	$hash->{AttrFn}  = 'SONOS_Attribute';
	$hash->{NotifyFn}  = 'SONOS_Notify';
	
	# CGI
	my $name = "sonos";
	my $fhem_url = "/" . $name ;
	$data{FWEXT}{$fhem_url}{FUNC} = "SONOS_FhemWebCallback";
	$data{FWEXT}{$fhem_url}{LINK} = $name;
	$data{FWEXT}{$fhem_url}{NAME} = undef;
	
	eval {
		no strict;
		no warnings;
		$hash->{AttrList}= 'pingType:'.join(',', @SONOS_PINGTYPELIST).' targetSpeakDir targetSpeakURL targetSpeakFileTimestamp:0,1 targetSpeakFileHashCache:0,1 Speak1 Speak2 Speak3 Speak4 SpeakCover Speak1Cover Speak2Cover Speak3Cover Speak4Cover generateProxyAlbumArtURLs:0,1 proxyCacheTime proxyCacheDir characterDecoding '.$readingFnAttributes;
		use strict;
		use warnings;
	};
	
	$data{RC_layout}{Sonos} = "SONOS_RCLayout";
	
	return undef;
}

########################################################################################
#
# SONOS_RCLayout - Returns the Standard-Layout-Definition for a RemoteControl-Device
#
########################################################################################
sub SONOS_RCLayout() {
	my @rows = ();
	
	push @rows, "Play:PLAY,Pause:PAUSE,Previous:REWIND,Next:FF,VolumeD:VOLDOWN,VolumeU:VOLUP,MuteT:MUTE";
	push @rows, "attr rc_iconpath icons/remotecontrol";
	push @rows, "attr rc_iconprefix black_btn_";
	
	return @rows;
}

########################################################################################
#
# SONOS_getCoverTitleRG - Returns the Cover- and Title-Readings for use in a ReadingsGroup
#
########################################################################################
sub SONOS_getCoverTitleRG($;$$) {
	my ($device, $width, $space) = @_;
	$width = 500 if (!defined($width));
	
	my $transportState = ReadingsVal($device, 'transportState', '');
	
	my $currentRuntime = 1;
	my $currentStarttime = 0;
	my $currentPosition = 0;
	my $normalAudio = ReadingsVal($device, 'currentNormalAudio', 0);
	if ($normalAudio) {
		$currentRuntime = SONOS_GetTimeSeconds(ReadingsVal($device, 'currentTrackDuration', '0:00:01'));
		$currentRuntime = 1 if (!$currentRuntime);
		
		$currentPosition = SONOS_GetTimeSeconds(ReadingsVal($device, 'currentTrackPosition', '0:00:00'));
		
		$currentStarttime = SONOS_GetTimeFromString(ReadingsTimestamp($device, 'currentTrackPosition', SONOS_TimeNow())) - $currentPosition;
	}
	
	my $playing = 0;
	if ($transportState eq 'PLAYING') {
		$playing = 1;
		$transportState = FW_makeImage('audio_play', 'Playing', 'SONOS_Transportstate');
	}
	$transportState = FW_makeImage('audio_pause', 'Paused', 'SONOS_Transportstate') if ($transportState eq 'PAUSED_PLAYBACK');
	$transportState = FW_makeImage('audio_stop', 'Stopped', 'SONOS_Transportstate') if ($transportState eq 'STOPPED');
	
	my $fullscreenDiv = '<style type="text/css">.SONOS_Transportstate { height: 0.8em; margin-top: -6px; margin-left: 2px; }</style><div id="cover_current'.$device.'" style="position: fixed; top: 0px; left: 0px; width: 100%; height: 100%; z-index: 10000; background-color: rgb(20,20,20);" onclick="document.getElementById(\'cover_current'.$device.'\').style.display = \'none\'; document.getElementById(\'global_fulldiv_'.$device.'\').innerHTML = \'\';"><div style="width: 100%; top 5px; text-align: center; font-weight: bold; color: lightgray; font-size: 200%;">'.ReadingsVal($device, 'roomName', $device).$transportState.'</div><div style="position: relative; top: 8px; height: 86%; max-width: 100%; text-align: center;"><img style="height: 100%; width: auto; border: 1px solid lightgray;" src="'.ReadingsVal($device, 'currentAlbumArtURL', '').'"/></div><div style="position: absolute; width: 100%; bottom: 8px; padding: 5px; text-align: center; font-weight: bold; color: lightgray; background-color: rgb(20,20,20); font-size: 120%;">'.ReadingsVal($device, 'infoSummarize1', '').'</div><div id="hash_'.$device.'" style="display: none; color: white;">'.md5_hex(ReadingsVal($device, 'roomName', $device).ReadingsVal($device, 'infoSummarize2', '').ReadingsVal($device, 'currentTrackPosition', '').ReadingsVal($device, 'currentAlbumArtURL', '')).'</div>'.(($normalAudio) ? '<div id="prog_runtime_'.$device.'" style="display: none; color: white;">'.$currentRuntime.'</div><div id="prog_starttime_'.$device.'" style="display: none; color: white;">'.$currentStarttime.'</div><div id="prog_playing_'.$device.'" style="display: none; color: white;">'.$playing.'</div><div id="progress'.$device.'" style="position: absolute; bottom: 0px; width: 100%; height: 2px; border: 1px solid #000; overflow: hidden;"><div id="progressbar'.$device.'" style="width: '.(($currentPosition * 100) / $currentRuntime).'%; height: 2px; border-right: 1px solid #000000; background: #d65946;"></div></div>' : '').'</div>';
	
	my $javascriptTimer = 'function refreshTime'.$device.'() {
		var playing = document.getElementById("prog_playing_'.$device.'");
		if (!playing || (playing && (playing.innerHTML == "0"))) {
			return;
		}
		
		var runtime = document.getElementById("prog_runtime_'.$device.'");
		var starttime = document.getElementById("prog_starttime_'.$device.'");
		if (runtime && starttime) {
			var now = new Date().getTime();
			var percent = (Math.round(now / 10.0) -  Math.round(starttime.innerHTML * 100.0)) / runtime.innerHTML;
			document.getElementById("progressbar'.$device.'").style.width = percent + "%";
			
			setTimeout(refreshTime'.$device.', 100);
		}
	}';
	
	my $javascriptText = '<script type="text/javascript">
		if (!document.getElementById("global_fulldiv_'.$device.'")) {
			var newDiv = document.createElement("div");
			newDiv.setAttribute("id", "global_fulldiv_'.$device.'");
			document.body.appendChild(newDiv);
			
			var newScript = document.createElement("script");
			newScript.setAttribute("type", "text/javascript");
			newScript.appendChild(document.createTextNode(\'function refreshFull'.$device.'() {
				var fullDiv = document.getElementById("element_fulldiv_'.$device.'");
				if (!fullDiv) {
					return;
				}
				var elementHTML = decodeURIComponent(fullDiv.innerHTML);
				var global = document.getElementById("global_fulldiv_'.$device.'");
				var oldGlobal = global.innerHTML;
				
				var hash = document.getElementById("hash_'.$device.'");
				var hashMatch = /<div id="hash_'.$device.'".*?>(.+?)<.div>/i;
				hashMatch.exec(elementHTML);
				
				if ((oldGlobal != "") && (!hash || (hash.innerHTML != RegExp.$1))) {
					global.innerHTML = elementHTML;
				}
				
				if (oldGlobal != "") {
					setTimeout(refreshFull'.$device.', 1000);
					var playing = document.getElementById("prog_playing_'.$device.'");
					if (playing && playing.innerHTML == "1") {
						setTimeout(refreshTime'.$device.', 100);
					}
				}
			} '.$javascriptTimer.'\'));
			
			document.body.appendChild(newScript);
		}
	</script>';
	
	$javascriptText =~ s/\n/ /g;
	return $javascriptText.'<div style="float: left;" onclick="document.getElementById(\'global_fulldiv_'.$device.'\').innerHTML = \'&nbsp;\'; refreshFull'.$device.'(); '.($playing ? 'refreshTime'.$device.'();' : '').'">'.SONOS_getCoverRG($device).'</div><div style="display: none;" id="element_fulldiv_'.$device.'">'.uri_escape($fullscreenDiv).'</div><div style="margin-left: 150px; min-width: '.$width.'px;">'.SONOS_getTitleRG($device, $space).'</div>';
}

########################################################################################
#
# SONOS_getCoverRG - Returns the Cover-Readings for use in a ReadingsGroup
#
########################################################################################
sub SONOS_getCoverRG($;$) {
	my ($device) = @_;
	
	return '<img style="margin-right: 5px; border: 1px solid lightgray; height: 175px" src="'.ReadingsVal($device, 'currentAlbumArtURL', '').'" />';
}

########################################################################################
#
# SONOS_getTitleRG - Returns the Title-Readings for use in a ReadingsGroup
#
########################################################################################
sub SONOS_getTitleRG($;$) {
	my ($device, $space) = @_;
	$space = 20 if (!defined($space));
	
	my $infoString = '';
	
	my $transportState = ReadingsVal($device, 'transportState', '');
	$transportState = 'Spiele' if ($transportState eq 'PLAYING');
	$transportState = 'Pausiere' if ($transportState eq 'PAUSED_PLAYBACK');
	$transportState = 'Stop bei' if ($transportState eq 'STOPPED');
  
	# Läuft Radio oder ein "normaler" Titel
	if (ReadingsVal($device, 'currentNormalAudio', 1) == 1) {
		my $showNext = ReadingsVal($device, 'nextTitle', '') || ReadingsVal($device, 'nextArtist', '') || ReadingsVal($device, 'nextAlbum', '');
		$infoString = sprintf('<div style="margin-left: -150px;">%s Titel %s von %s<br />Titel: <b>%s</b><br />Interpret: <b>%s</b><br />Album: <b>%s</b>'.($showNext ? '<div style="height: %dpx;"></div>Nächste Wiedergabe:</div><div style="float: left; margin-left: 0px;"><img style="margin: 0px; padding: 0px; margin-right: 5px; border: 1px solid lightgray;" height="55"  border="0" src="%s" /></div><div style="margin-left: 0px;">Titel: %s<br />Artist: %s<br />Album: %s</div>' : ''),
				$transportState, 
				ReadingsVal($device, 'currentTrack', ''), 
				ReadingsVal($device, 'numberOfTracks', ''),
				ReadingsVal($device, 'currentTitle', ''),
				ReadingsVal($device, 'currentArtist', ''),
				ReadingsVal($device, 'currentAlbum', ''),
				$space,
				ReadingsVal($device, 'nextAlbumArtURL', ''),
				ReadingsVal($device, 'nextTitle', ''),
				ReadingsVal($device, 'nextArtist', ''),
				ReadingsVal($device, 'nextAlbum', ''));
	} else {
		$infoString = sprintf('<div style="margin-left: -150px;">%s Radiostream<br />Sender: <b>%s</b><br />Info: <b>%s</b><br />Läuft: <b>%s</b></div>',
				$transportState,
				ReadingsVal($device, 'currentSender', ''),
				ReadingsVal($device, 'currentSenderInfo', ''),
				ReadingsVal($device, 'currentSenderCurrent', ''));
	}
	
	return $infoString;
}

########################################################################################
#
# SONOS_getListRG - Returns the approbriate list-Reading for use in a ReadingsGroup
#
########################################################################################
sub SONOS_getListRG($$;$) {
	my ($device, $reading, $ul) = @_;
	$ul = 0 if (!defined($ul));
	
	my $resultString = '';
	
	# Manchmal ist es etwas komplizierter mit den Zeichensätzen...
	my %elems = %{eval(decode('CP1252', ReadingsVal($device, $reading, '{}')))};
	
	for my $key (keys %elems) {
		my $command;
		if ($reading eq 'Favourites') {
			$command = 'cmd.'.$device.uri_escape('=set '.$device.' StartFavourite '.uri_escape($elems{$key}->{Title}));
		} elsif ($reading eq 'Playlists') {
			$command = 'cmd.'.$device.uri_escape('=set '.$device.' StartPlaylist '.uri_escape($elems{$key}->{Title}));
		} elsif ($reading eq 'Radios') {
			$command = 'cmd.'.$device.uri_escape('=set '.$device.' StartRadio '.uri_escape($elems{$key}->{Title}));
		}
		$command = "FW_cmd('/fhem?XHR=1&$command')";
		
		if ($ul) {
			$resultString .= '<li style="list-style-type: none; display: inline;"><a onclick="'.$command.'"><img style="border: solid 1px lightgray; margin: 3px;" width="70" src="'.$elems{$key}->{Cover}.'" /></a></li>';
		} else {
			$resultString .= '<tr><td><img width="70" src="'.$elems{$key}->{Cover}.'" /></td><td><a onclick="'.$command.'">'.$elems{$key}->{Title}."</a></td></tr>\n";
		}
	}
	
	if ($ul) {
		return '<ul style="margin-left: 0px; padding-left: 0px; list-style-type: none; display: inline;">'.$resultString.'</ul>';
	} else {
		return '<table>'.$resultString.'</table>';
	}
}

########################################################################################
#
# SONOS_getGroupsRG -  Returns a simple group-constellation-list for use in a ReadingsGroup
#
########################################################################################
sub SONOS_getGroupsRG() {
	my $groups = CommandGet(undef, SONOS_getDeviceDefHash(undef)->{NAME}.' Groups');
	
	my $result = '<ul>';
	my $i = 0;
	while ($groups =~ m/\[(.*?)\]/ig) {
		my @member = split(/, /, $1);
		@member = map FW_makeImage('icoSONOSPLAYER_icon-'.ReadingsVal($_, 'playerType', '').'.png', '', '').ReadingsVal($_, 'roomName', $_), @member;
		
		$result .= '<li>'.++$i.'. Gruppe:<ul style="list-style-type: none; padding-left: 0px;"><li>'.join('</li><li>', @member).'</li></ul></li>';
	}
	return $result.'</ul>';
}

########################################################################################
#
# SONOS_FhemWebCallback -  Implements a Webcallback e.g. a small proxy for Cover-images.
#
########################################################################################
sub SONOS_FhemWebCallback($) {
	my ($URL) = @_;
	
	# Einfache Grundprüfungen
	return ("text/html; charset=UTF8", 'Fehlerhafte Anfrage: '.$URL) if ($URL !~ m/^\/sonos\//i);
	$URL =~ s/^\/sonos//i;
	
	# Proxy-Features...
	if ($URL =~ m/^\/proxy\//i) {
		return ("text/html; charset=UTF8", 'Proxybetrieb nicht aktiviert: '.$URL) if (!AttrVal(SONOS_getDeviceDefHash(undef)->{NAME}, 'generateProxyAlbumArtURLs', 0));
		
		my $proxyCacheTime = AttrVal(SONOS_getDeviceDefHash(undef)->{NAME}, 'proxyCacheTime', 0);
		my $proxyCacheDir = AttrVal(SONOS_getDeviceDefHash(undef)->{NAME}, 'proxyCacheDir', '/tmp');
		$proxyCacheDir =~ s/\\/\//g;
		
		# Zurückzugebende Adresse ermitteln...
		my $albumurl = uri_unescape($1) if ($URL =~ m/^\/proxy\/aa\?url=(.*)/i);
		
		# Nur für Sonos-Player den Proxy spielen (und für Spotify-Links)
		my $ip = '';
		$ip = $1 if ($albumurl =~ m/^http:\/\/(.*?)[:\/]/i);
		for my $player (SONOS_getAllSonosplayerDevices()) {
			if (ReadingsVal($player->{NAME}, 'location', '') =~ m/^http:\/\/$ip:/i) {
				undef($ip);
				last;
			}
		}
		return ("text/html; charset=UTF8", 'Anfrage für Nicht-Sonos-Player: '.$URL) if ($ip && $URL !~ /\/original\//i);
		
		# Generierter Dateiname für die Cache-Funktionalitaet
		my $albumHash;
		
		# Schauen, ob die Datei aus dem Cache bedient werden kann...
		if ($proxyCacheTime) {
			eval {
				require Digest::SHA1;
				import Digest::SHA1 qw(sha1_hex);
				$albumHash = $proxyCacheDir.'/SonosProxyCache_'.sha1_hex(lc($albumurl)).'.image';
			};
			
			if ((-e $albumHash) && ((stat($albumHash)->mtime) + $proxyCacheTime > gettimeofday())) {
				SONOS_Log undef, 5, 'Cover wird aus Cache bedient: '.$albumHash.' ('.$albumurl.')';
				
				$albumHash =~ m/(.*)\/(.*)\.(.*)/;
				FW_serveSpecial($2, $3, $1, 1);
				
				return(undef, undef);
			}
		}
		
		# Bild vom Player holen...
		my $ua = LWP::UserAgent->new(agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, likeGecko) Chrome/23.0.1271.64 Safari/537.11');
		my $response = $ua->get($albumurl);
		if ($response->is_success) {
			SONOS_Log undef, 5, 'Cover wurde neu geladen: '.$albumurl;
			
			my $tempFile;
			if ($proxyCacheTime) {
				unlink $albumHash if (-e $albumHash);
				SONOS_Log undef, 5, 'Cover wird im Cache abgelegt: '.$albumHash.' ('.$albumurl.')';
			} else {
				# Da wir die Standard-Prozedur 'FW_serveSpecial' aus 'FHEMWEB' verwenden moechten, brauchen wir eine lokale Datei
				$tempFile = File::Temp->new(SUFFIX => '.image');
				$albumHash = $tempFile->filename;
				$albumHash =~ s/\\/\//g;
				SONOS_Log undef, 5, 'TempFilename: '.$albumHash;
			}
			
			# Either Tempfile or Cachefile...
			SONOS_WriteFile($albumHash, $response->content);
			
			$albumHash =~ m/(.*)\/(.*)\.(.*)/;
			FW_serveSpecial($2, $3, $1, 1);
			
			return (undef, undef);
		}
	}
	
	# Cover-Features...
	if ($URL =~ m/^\/cover\//i) {
		$URL =~ s/^\/cover//i;
		
		if ($URL =~ m/^\/empty.jpg/i) {
			FW_serveSpecial('sonos_empty', 'jpg', $attr{global}{modpath}.'/FHEM/lib/UPnP', 1);
			return (undef, undef);
		}
		
		if ($URL =~ m/^\/playlist.jpg/i) {
			return FW_serveSpecial('sonos_playlist', 'jpg', $attr{global}{modpath}.'/FHEM/lib/UPnP', 1);
			return (undef, undef);
		}
		
		if ($URL =~ m/^\/input_default.jpg/i) {
			return FW_serveSpecial('sonos_input_default', 'jpg', $attr{global}{modpath}.'/FHEM/lib/UPnP', 1);
			return (undef, undef);
		}
		
		if ($URL =~ m/^\/input_tv.jpg/i) {
			return FW_serveSpecial('sonos_input_tv', 'jpg', $attr{global}{modpath}.'/FHEM/lib/UPnP', 1);
			return (undef, undef);
		}
		
		# Wird im Prinzip einfach nicht mehr aufgerufen...
		#if ($URL =~ m/^\/favorit\?res=(.*)/i) {
		#	my $resURL = uri_unescape($1);
		#	
		#	if ($resURL =~ m/^(x-rincon-cpcontainer|x-sonos-spotify).*?(spotify.*?)(\?|$)/i) {
		#		my $infos = get('https://embed.spotify.com/oembed/?url='.$2);
		#		
		#		if ($infos =~ m/"thumbnail_url":"(.*?)cover(.*?)"/i) {
		#			$resURL = $1.'original'.$2;
		#			$resURL =~ s/\\//g;
		#		}
		#	} elsif($URL =~ m/savedqueues.rsq/i) {
		#		$resURL = $attr{global}{modpath}.'/FHEM/lib/UPnP/sonos_playlist.jpg';
		#	} else {
		#		my @player = SONOS_getAllSonosplayerDevices();
		#		my $stream = 0;
		#		$stream = 1 if ($resURL =~ /x-sonosapi-stream/);
		#		$resURL = $1.'/getaa?'.($stream ? 's=1&' : '').'u='.uri_escape($resURL) if (ReadingsVal($player[0]->{NAME}, 'location', '') =~ m/^(http:\/\/.*?:.*?)\//i);
		#	}
		#		
		#	if ($resURL) {
		#		SONOS_Log undef, 5, 'Hole Cover: '.$resURL;
		#		
		#		if ($resURL =~ /^http/) {
		#			# Bild holen...
		#			my $ua = LWP::UserAgent->new(agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, likeGecko) Chrome/23.0.1271.64 Safari/537.11');
		#			my $response = $ua->get($resURL);
		#			if ($response->is_success) {
		#				return ($response->header('Content-Type').'; charset=UTF8', $response->content);
		#			}
		#		} else {
		#			return ('charset=UTF8', SONOS_ReadFile($resURL));
		#		}
		#	}
		#}
	}
	
	# Wenn wir hier ankommen, dann konnte nichts verarbeitet werden...
	return ("text/html; charset=UTF8", 'Fehlerhafte Anfrage: '.$URL);
}

########################################################################################
#
# SONOS_Define - Implements DefFn function
# 
# Parameter hash = hash of device addressed
#						def = definition string
#
########################################################################################
sub SONOS_Define($$) {
	my ($hash, $def) = @_;
	my @a = split("[ \t]+", $def);
  
	# check syntax
	return 'Usage: define <name> SONOS [[[[upnplistener] interval] waittime] delaytime]' if($#a < 2 || $#a > 5);
	my $name = $a[0];
	
	my $upnplistener;
	if ($a[2] && !looks_like_number($a[2])) {
		$upnplistener = $a[2];
	} else {
		$upnplistener = 'localhost:4711';
	}
	
	my $interval;
	if (looks_like_number($a[3])) {
		$interval = $a[3];
		if ($interval < 10) {
			SONOS_Log undef, 0, 'Interval has to be a minimum of 10 sec. and not: '.$interval;
			$interval = 10;
		}
	} else {
		$interval = 10;
	}
	
	my $waittime;
	if (looks_like_number($a[4])) {
		$waittime = $a[4];
	} else {
		$waittime = 8;
	}
	
	my $delaytime;
	if (looks_like_number($a[5])) {
		$delaytime = $a[5];
	} else {
		$delaytime = 0;
	}
	
	$hash->{NAME} = $name;
	$hash->{DeviceName} = $upnplistener;
	$hash->{INTERVAL} = $interval;
	$hash->{WAITTIME} = $waittime;
	$hash->{DELAYTIME} = $delaytime;
	$hash->{STATE} = 'waiting for subprocess...';
	
	if ($hash->{DELAYTIME}) {
		InternalTimer(gettimeofday() + $hash->{DELAYTIME}, 'SONOS_DelayStart', $hash, 0);
	} else {
		SONOS_DelayStart($hash);
	}
	
	return undef;
}

########################################################################################
#
#  SONOS_DelayStart - Starts the SubProcess with a Delay. Can solute problems with blocked Ports
#
########################################################################################
sub SONOS_DelayStart($) {
	my ($hash) = @_;
	
	# Prüfen, ob ein Server erreichbar wäre, und wenn nicht, einen Server starten
	SONOS_StartClientProcessIfNeccessary($hash->{DeviceName});
	
	InternalTimer(gettimeofday() + $hash->{WAITTIME}, 'SONOS_DelayOpenDev', $hash, 0);
}

########################################################################################
#
#  SONOS_DelayOpenDev - Starts the IO-Connection with a Delay.
#
########################################################################################
sub SONOS_DelayOpenDev($) {
	my ($hash) = @_;
	
	# Die Datenverbindung zu dem gemachten Server hier starten und initialisieren
	DevIo_OpenDev($hash, 0, "SONOS_InitClientProcessLater");
}

########################################################################################
#
#  SONOS_Attribute - Implements AttrFn function 
#
########################################################################################
sub SONOS_Attribute($$$@) {
	my ($mode, $devName, $attrName, $attrValue) = @_;
	
	if ($mode eq 'set') {
		if ($attrName eq 'verbose') {
			SONOS_DoWork('undef', 'setVerbose', $attrValue);
		}
	}
	
	return undef;
}

########################################################################################
#
#  SONOS_Notify - Implements NotifyFn function 
#
########################################################################################
sub SONOS_Notify() {
	my ($hash, $notifyhash) = @_;
	
	return undef;
	
	#if (($notifyhash->{NAME} eq 'global') && ($notifyhash->{CHANGED}[0] eq 'REREADCFG')) {
	#	SONOS_Log undef, 0, 'Detecting rereadcfg. Restart Sonos-Subprocess...';
	#	
	#	# Vorab warten, da im Hintergrund der Thread noch läuft und auch erstmal fertig werden muss...
	#	select(undef, undef, undef, $hash->{WAITTIME});
	#	
	#	# Verbindung beenden, damit der SubProzess die Chance hat neu initialisiert zu werden...
	#	RemoveInternalTimer($hash);
	#	DevIo_SimpleWrite($hash, "disconnect\n", 0);
	#	DevIo_CloseDev($hash);
	#	
	#	# Neu anstarten...
	#	SONOS_StartClientProcessIfNeccessary($hash->{DeviceName}) if ($SONOS_StartedOwnUPnPServer);
	#	InternalTimer(gettimeofday() + $hash->{WAITTIME}, 'SONOS_DelayOpenDev', $hash, 0);
	#}
	#
	#return undef;
}

########################################################################################
#
# SONOS_Ready - Implements ReadyFn function
# 
# Parameter hash = hash of device addressed
#
########################################################################################
sub SONOS_Ready($) {
	my ($hash) = @_;
	
	return DevIo_OpenDev($hash, 1, "SONOS_InitClientProcessLater");
}

########################################################################################
#
# SONOS_Read - Implements ReadFn function
# 
# Parameter hash = hash of device addressed
#
########################################################################################
sub SONOS_Read($) {
	my ($hash) = @_;
	
	# Bis zum letzten (damit der Puffer leer ist) Zeilenumbruch einlesen, da SimpleRead immer nur 256-Zeichen-Päckchen einliest.
	my $buf = DevIo_DoSimpleRead($hash);
	
	# Wenn hier gar nichts gekommen ist, dann diesen Aufruf beenden...
	if (!defined($buf) || ($buf eq '')) {
		SONOS_Log undef, 1, 'Nothing could be read from TCP-Channel (the first level) even though the Read-Function was called.';
		
		# Verbindung beenden, damit der SubProzess die Chance hat neu initialisiert zu werden...
		RemoveInternalTimer($hash);
		DevIo_SimpleWrite($hash, "disconnect\n", 0);
		DevIo_CloseDev($hash);
		
		# Neu anstarten...
		SONOS_StartClientProcessIfNeccessary($hash->{DeviceName}) if ($SONOS_StartedOwnUPnPServer);
		InternalTimer(gettimeofday() + $hash->{WAITTIME}, 'SONOS_DelayOpenDev', $hash, 0);
		
		return;
	}
	
	# Wenn noch nicht alles gekommen ist, dann hier auf den Rest warten...
	while (substr($buf, -1, 1) ne "\n") {
		my $newRead = DevIo_SimpleRead($hash);
		
		# Wenn hier gar nichts gekommen ist, dann diesen Aufruf beenden...
		if (!defined($newRead) || ($newRead eq '')) {
			SONOS_Log undef, 1, 'Nothing could be read from TCP-Channel (the second level) even though the Read-Function was called. The client is now directed to shutdown and the connection should be re-initialized...';
			
			# Verbindung beenden, damit der SubProzess die Chance hat neu initialisiert zu werden...
			RemoveInternalTimer($hash);
			DevIo_SimpleWrite($hash, "disconnect\n", 0);
			DevIo_CloseDev($hash);
			
			# Neu anstarten...
			SONOS_StartClientProcessIfNeccessary($hash->{DeviceName}) if ($SONOS_StartedOwnUPnPServer);
			InternalTimer(gettimeofday() + $hash->{WAITTIME}, 'SONOS_DelayOpenDev', $hash, 0);
			
			return;
		}
		
		# Wenn es neue Daten gibt, dann anhängen...
		$buf .= $newRead;
	}
	
	# Die aktuellen Abspielinformationen werden Schritt für Schritt übertragen, gesammelt und dann in einem Rutsch ausgewertet.
	# Dafür eignet sich eine Sub-Statische Variable am Besten	
	state %current;
	
	# Hier könnte jetzt eine ganze Liste von Anweisungen enthalten sein, die jedoch einzeln verarbeitet werden müssen
	# Dabei kann der Trenner ein Zeilenumbruch sein, oder ein Tab-Zeichen.
	foreach my $line (split(/[\n\a]/, $buf)) {
		# Abschließende Zeilenumbrüche abschnippeln
		$line =~ s/[\r\n]*$//;
		
		SONOS_Log undef, 5, "Received from UPnP-Server: '$line'";
		
		# Hier empfangene Werte verarbeiten
		if ($line =~ m/^ReadingsSingleUpdateIfChanged:(.*?):(.*?):(.*)/) {
			if (lc($1) eq 'undef') {
				SONOS_readingsSingleUpdateIfChanged(SONOS_getDeviceDefHash(undef), $2, $3, 1);
			} else {
				my $hash = SONOS_getSonosPlayerByUDN($1);
			
				if ($hash) {
					SONOS_readingsSingleUpdateIfChanged($hash, $2, $3, 1);
				} else {
					SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsSingleUpdateIfChanged: $1:$2:$3";
				}
			}
		} elsif ($line =~ m/^ReadingsSingleUpdateIfChangedNoTrigger:(.*?):(.*?):(.*)/) {
			if (lc($1) eq 'undef') {
				SONOS_readingsSingleUpdateIfChanged(SONOS_getDeviceDefHash(undef), $2, $3, 0);
			} else {
				my $hash = SONOS_getSonosPlayerByUDN($1);
			
				if ($hash) {
					SONOS_readingsSingleUpdateIfChanged($hash, $2, $3, 0);
				} else {
					SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsSingleUpdateIfChangedNoTrigger: $1:$2:$3";
				}
			}
		} elsif ($line =~ m/^ReadingsSingleUpdate:(.*?):(.*?):(.*)/) {
			if (lc($1) eq 'undef') {
				readingsSingleUpdate(SONOS_getDeviceDefHash(undef), $2, $3, 1);
			} else {
				my $hash = SONOS_getSonosPlayerByUDN($1);
			
				if ($hash) {
					readingsSingleUpdate($hash, $2, $3, 1);
				} else {
					SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsSingleUpdate: $1:$2:$3";
				}
			}
		} elsif ($line =~ m/^ReadingsBulkUpdate:(.*?):(.*?):(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				readingsBulkUpdate($hash, $2, $3);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsBulkUpdate: $1:$2:$3";
			}
		} elsif ($line =~ m/^ReadingsBulkUpdateIfChanged:(.*?):(.*?):(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				SONOS_readingsBulkUpdateIfChanged($hash, $2, $3);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsBulkUpdateIfChanged: $1:$2:$3";
			}
		} elsif ($line =~ m/ReadingsBeginUpdate:(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				readingsBeginUpdate($hash);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsBeginUpdate: $1";
			}
		} elsif ($line =~ m/ReadingsEndUpdate:(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				readingsEndUpdate($hash, 1);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von ReadingsEndUpdate: $1";
			}
		} elsif ($line =~ m/CommandDefine:(.*)/) {
			CommandDefine(undef, $1);
		} elsif ($line =~ m/CommandAttr:(.*)/) {
			CommandAttr(undef, $1);
		} elsif ($line =~ m/GetReadingsToCurrentHash:(.*?):(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				%current = SONOS_GetReadingsToCurrentHash($hash->{NAME}, $2);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von GetReadingsToCurrentHash: $1:$2";
			}
		} elsif ($line =~ m/SetCurrent:(.*?):(.*)/) {
			$current{$1} = $2;
		} elsif ($line =~ m/CurrentBulkUpdate:(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				readingsBeginUpdate($hash);
				
				# Dekodierung durchführen
				$current{Title} = decode_entities($current{Title});
				$current{Artist} = decode_entities($current{Artist});
				$current{Album} = decode_entities($current{Album});
				$current{AlbumArtist} = decode_entities($current{AlbumArtist});
				
				$current{Sender} = decode_entities($current{Sender});
				$current{SenderCurrent} = decode_entities($current{SenderCurrent});
				$current{SenderInfo} = decode_entities($current{SenderInfo});
				
				$current{nextTitle} = decode_entities($current{nextTitle});
				$current{nextArtist} = decode_entities($current{nextArtist});
				$current{nextAlbum} = decode_entities($current{nextAlbum});
				$current{nextAlbumArtist} = decode_entities($current{nextAlbumArtist});
			
				SONOS_readingsBulkUpdateIfChanged($hash, "transportState", $current{TransportState});
				SONOS_readingsBulkUpdateIfChanged($hash, "Shuffle", $current{Shuffle});
				SONOS_readingsBulkUpdateIfChanged($hash, "Repeat", $current{Repeat});
				SONOS_readingsBulkUpdateIfChanged($hash, "CrossfadeMode", $current{CrossfadeMode});
				SONOS_readingsBulkUpdateIfChanged($hash, "SleepTimer", $current{SleepTimer});
				SONOS_readingsBulkUpdateIfChanged($hash, "AlarmRunning", $current{AlarmRunning});
				SONOS_readingsBulkUpdateIfChanged($hash, "AlarmRunningID", $current{AlarmRunningID});
				SONOS_readingsBulkUpdateIfChanged($hash, "numberOfTracks", $current{NumberOfTracks});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentTrack", $current{Track});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentTrackURI", $current{TrackURI});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentTrackDuration", $current{TrackDuration});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentTrackPosition", $current{TrackPosition});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentTitle", $current{Title});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentArtist", $current{Artist});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentAlbum", $current{Album});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentOriginalTrackNumber", $current{OriginalTrackNumber});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentAlbumArtist", $current{AlbumArtist});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentAlbumArtURL", $current{AlbumArtURL});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentSender", $current{Sender});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentSenderCurrent", $current{SenderCurrent});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentSenderInfo", $current{SenderInfo});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentStreamAudio", $current{StreamAudio});
				SONOS_readingsBulkUpdateIfChanged($hash, "currentNormalAudio", $current{NormalAudio});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextTrackDuration", $current{nextTrackDuration});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextTrackURI", $current{nextTrackURI});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextTitle", $current{nextTitle});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextArtist", $current{nextArtist});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextAlbum", $current{nextAlbum});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextAlbumArtist", $current{nextAlbumArtist});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextAlbumArtURL", $current{nextAlbumArtURL});
				SONOS_readingsBulkUpdateIfChanged($hash, "nextOriginalTrackNumber", $current{nextOriginalTrackNumber});
				SONOS_readingsBulkUpdateIfChanged($hash, "Volume", $current{Volume});
				SONOS_readingsBulkUpdateIfChanged($hash, "Mute", $current{Mute});
				SONOS_readingsBulkUpdateIfChanged($hash, "Balance", $current{Balance});
				SONOS_readingsBulkUpdateIfChanged($hash, "HeadphoneConnected", $current{HeadphoneConnected});
				
				my $name = $hash->{NAME};
				
				# If the SomethingChanged-Event should be triggered, do so. It's useful if one would be triggered if even some changes are made, and it's unimportant to exactly know what
				if (AttrVal($name, 'generateSomethingChangedEvent', 0) == 1) {
					readingsBulkUpdate($hash, "somethingChanged", 1);
				}
				
				# If the Info-Summarize is configured to be triggered. Here one can define a single information-line with all the neccessary informations according to the type of Audio
				SONOS_ProcessInfoSummarize($hash, \%current, 'InfoSummarize1', 1);
				SONOS_ProcessInfoSummarize($hash, \%current, 'InfoSummarize2', 1);
				SONOS_ProcessInfoSummarize($hash, \%current, 'InfoSummarize3', 1);
				SONOS_ProcessInfoSummarize($hash, \%current, 'InfoSummarize4', 1);
				
				# Zusätzlich noch den STATE und das Reading State mit dem vom Anwender gewünschten Wert aktualisieren, Dabei müssen aber doppelte Anführungszeichen vorher maskiert werden...
				SONOS_readingsBulkUpdateIfChanged($hash, 'state', $current{AttrVal($name, 'stateVariable', 'TransportState')});
			  
				# End the Bulk-Update, and trigger events
				SONOS_readingsEndUpdate($hash, 1);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von CurrentBulkUpdate: $1";
			}
		} elsif ($line =~ m/ProcessCover:(.*?):(.*?):(.*?):(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			if ($hash) {
				my $name = $hash->{NAME};
				
				my $nextReading = 'current';
				my $nextName = '';
				if ($2) {
					$nextReading = 'next';
					$nextName = 'Next';
				}
					
				my $tempURI = $3;
				my $groundURL = $4;
				my $currentValue;
			
				my $srcURI = '';
				if (defined($tempURI) && $tempURI ne '') {
					if ($tempURI =~ m/getaa.*?x-sonos-spotify.*?(spotify.*)%3f/i) {
						my $infos = get('https://embed.spotify.com/oembed/?url='.$1);
						
						if ($infos =~ m/"thumbnail_url":"(.*?)cover(.*?)"/i) {
							$srcURI = $1.'original'.$2;
							$srcURI =~ s/\\//g;
							$currentValue = $attr{global}{modpath}.'/www/images/default/SONOSPLAYER/'.$name.'_'.$nextName.'AlbumArt.jpg';
							SONOS_Log undef, 4, "Transport-Event: Spotify-Bilder-Download: SONOS_DownloadReplaceIfChanged('$srcURI', '".$currentValue."');";
						} else {
							$srcURI = $groundURL.$tempURI;
							$currentValue = $attr{global}{modpath}.'/www/images/default/SONOSPLAYER/'.$name.'_'.$nextName.'AlbumArt.'.SONOS_ImageDownloadTypeExtension($groundURL.$tempURI);
							SONOS_Log undef, 4, "Transport-Event: Spotify-Bilder-Download failed. Use normal thumbnail: SONOS_DownloadReplaceIfChanged('$srcURI', '".$currentValue."');";
						}
					} elsif ($tempURI =~ m/^\/fhem\/sonos\/cover\/(.*)/i) {
						$srcURI = $attr{global}{modpath}.'/FHEM/lib/UPnP/sonos_'.$1;
						$currentValue = $attr{global}{modpath}.'/www/images/default/SONOSPLAYER/'.$name.'_'.$nextName.'AlbumArt.jpg';
						SONOS_Log undef, 4, "Transport-Event: Cover-Copy: SONOS_DownloadReplaceIfChanged('$srcURI', '".$currentValue."');";
					} else {
						$srcURI = $groundURL.$tempURI;
						$currentValue = $attr{global}{modpath}.'/www/images/default/SONOSPLAYER/'.$name.'_'.$nextName.'AlbumArt.'.SONOS_ImageDownloadTypeExtension($groundURL.$tempURI);
						SONOS_Log undef, 4, "Transport-Event: Bilder-Download: SONOS_DownloadReplaceIfChanged('$srcURI', '".$currentValue."');";
					}
				} else {
					$srcURI = $attr{global}{modpath}.'/FHEM/lib/UPnP/sonos_empty.jpg';
					$currentValue = $attr{global}{modpath}.'/www/images/default/SONOSPLAYER/'.$name.'_'.$nextName.'AlbumArt.png';
					SONOS_Log undef, 4, "Transport-Event: CoverArt konnte nicht gefunden werden. Verwende FHEM-Logo. Bilder-Download: SONOS_DownloadReplaceIfChanged('$srcURI', '".$currentValue."');";
				}
				mkpath($attr{global}{modpath}.'/www/images/default/SONOSPLAYER/');
				my $filechanged = SONOS_DownloadReplaceIfChanged($srcURI, $currentValue);
				# Icons neu einlesen lassen, falls die Datei neu ist
				SONOS_RefreshIconsInFHEMWEB('/www/images/default/SONOSPLAYER/') if ($filechanged);
				
				# Die URL noch beim aktuellen Titel mitspeichern
				my $URL = $srcURI;
				if ($URL =~ m/\/lib\/UPnP\/sonos_(.*)/i) {
					$URL = '/fhem/sonos/cover/'.$1;
				} else {
					my $sonosName = SONOS_getDeviceDefHash(undef)->{NAME};
					$URL = '/fhem/sonos/proxy/aa?url='.uri_escape($URL) if (AttrVal($sonosName, 'generateProxyAlbumArtURLs', 0));
				}
				
				if ($nextReading eq 'next') {
					$current{nextAlbumArtURL} = $URL;
				} else {
					$current{AlbumArtURL} = $URL;
				}
				
				# This URI change rarely, but the File itself change nearly with every song, so trigger it everytime the content was different to the old one
				if ($filechanged) {
					readingsSingleUpdate($hash, $nextReading.'AlbumArtURI', $currentValue, 1);
				} else {
					SONOS_readingsSingleUpdateIfChanged($hash, $nextReading.'AlbumArtURI', $currentValue, 1);
				}
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von ProcessCover: $1:$2:$3:$4";
			}
		} elsif ($line =~ m/^SetAlarm:(.*?):(.*?);(.*?):(.*)/) {
			my $hash = SONOS_getSonosPlayerByUDN($1);
			
			my @alarmIDs = split(/,/, $3);
			
			if ($4) {
				readingsSingleUpdate($hash, 'AlarmList', $4, 0);
			} else {
				readingsSingleUpdate($hash, 'AlarmList', '{}', 0);
			}
			SONOS_readingsSingleUpdateIfChanged($hash, 'AlarmListIDs', join(',', sort {$a <=> $b} @alarmIDs), 0);
			SONOS_readingsSingleUpdateIfChanged($hash, 'AlarmListVersion', $2, 1);
		} elsif ($line =~ m/QA:(.*?):(.*?):(.*)/) { # Wenn ein QA (Question-Attribut) gefordert wurde, dann auch zurückliefern
			DevIo_SimpleWrite($hash, SONOS_AnswerQuery($line), 0);
		} elsif ($line =~ m/QR:(.*?):(.*?):(.*)/) { # Wenn ein QR (Question-Reading) gefordert wurde, dann auch zurückliefern
			DevIo_SimpleWrite($hash, SONOS_AnswerQuery($line), 0);
		} elsif ($line =~ m/QD:(.*?):(.*?):(.*)/) { # Wenn ein QD (Question-Definition) gefordert wurde, dann auch zurückliefern
			DevIo_SimpleWrite($hash, SONOS_AnswerQuery($line), 0);
		} elsif ($line =~ m/DoWorkAnswer:(.*?):(.*?):(.*)/) {
			my $chash;
			if (lc($1) eq 'undef') {
				$chash = SONOS_getDeviceDefHash(undef);
			} else {
				$chash = SONOS_getSonosPlayerByUDN($1);
			}
			
			if ($chash) {
				SONOS_Log undef, 4, "DoWorkAnswer arrived for ".$chash->{NAME}."->$2: '$3'"; 
				readingsSingleUpdate($chash, $2, $3, 1);
			} else {
				SONOS_Log undef, 0, "Fehlerhafter Aufruf von DoWorkAnswer: $1:$2:$3";
			}
		} else {
			SONOS_DoTriggerInternal('Main', $line);
		}
	}
}

########################################################################################
#
# SONOS_AnswerQuery - Create the approbriate answer for the given Question
#
# Parameter line = The line of Question
#
########################################################################################
sub SONOS_AnswerQuery($) {
	my ($line) = @_;
	
	if ($line =~ m/QA:(.*?):(.*?):(.*)/) { # Wenn ein QA (Question-Attribut) gefordert wurde, dann auch zurückliefern
		my $chash;
		if (lc($1) eq 'undef') {
			$chash = SONOS_getDeviceDefHash(undef);
		} else {
			$chash = SONOS_getSonosPlayerByUDN($1);
		}
		
		if ($chash) {
			SONOS_Log undef, 4, "QA-Anfrage(".$chash->{NAME}."): $1:$2:$3";
			return "A:$1:$2:".AttrVal($chash->{NAME}, $2, $3)."\r\n";
		} else {
			SONOS_Log undef, 1, "Fehlerhafte QA-Anfrage: $1:$2:$3"; 
			return "A:$1:$2:$3\r\n";
		}
	} elsif ($line =~ m/QR:(.*?):(.*?):(.*)/) { # Wenn ein QR (Question-Reading) gefordert wurde, dann auch zurückliefern
		my $chash;
		if (lc($1) eq 'undef') {
			$chash = SONOS_getDeviceDefHash(undef);
		} else {
			$chash = SONOS_getSonosPlayerByUDN($1);
		}
		
		if ($chash) {
			SONOS_Log undef, 4, "QR-Anfrage(".$chash->{NAME}."): $1:$2:$3";
			return "R:$1:$2:".ReadingsVal($chash->{NAME}, $2, $3)."\r\n";
		} else {
			SONOS_Log undef, 1, "Fehlerhafte QR-Anfrage: $1:$2:$3";
			return "R:$1:$2:$3\r\n";
		}
	} elsif ($line =~ m/QD:(.*?):(.*?):(.*)/) { # Wenn ein QD (Question-Definition) gefordert wurde, dann auch zurückliefern
		my $chash;
		if (lc($1) eq 'undef') {
			$chash = SONOS_getDeviceDefHash(undef);
		} else {
			$chash = SONOS_getSonosPlayerByUDN($1);
		}
		
		if ($chash) {
			SONOS_Log undef, 4, "QD-Anfrage(".$chash->{NAME}."): $1:$2:$3";
			if ($chash->{$2}) {
				return "D:$1:$2:".$chash->{$2}."\r\n";
			} else {
				return "D:$1:$2:$3\r\n";
			}
		} else {
			SONOS_Log undef, 1, "Fehlerhafte QD-Anfrage: $1:$2:$3";
			return "D:$1:$2:$3\r\n";
		}
	}
}

########################################################################################
#
# SONOS_StartClientProcess - Starts the client-process (in a forked-subprocess), which handles all UPnP-Messages
#
# Parameter port = Portnumber to what the client have to listen for
#
########################################################################################
sub SONOS_StartClientProcessIfNeccessary($) {
	my ($upnplistener) = @_;
	my ($host, $port) = split(/:/, $upnplistener);
	
	my $socket = new IO::Socket::INET(PeerAddr => $upnplistener, Proto => 'tcp');
	if (!$socket) {
		# Sonos-Device ermitteln...
		my $hash = SONOS_getDeviceDefHash(undef);
		
		SONOS_Log undef, 1, 'Kein UPnP-Server gefunden... Starte selber einen und warte '.$hash->{WAITTIME}.' Sekunde(n) darauf...';
		$SONOS_StartedOwnUPnPServer = 1;
		
		if (fork() == 0) {
			# Zuständigen Verbose-Level ermitteln...
			# Allerdings sind die Attribute (momentan) zu diesem Zeitpunkt noch nicht gesetzt, sodass nur das globale Attribut verwendet werden kann...
			my $verboselevel = AttrVal(SONOS_getDeviceDefHash(undef)->{NAME}, 'verbose', $attr{global}{verbose});
			
			# Prozess anstarten...
			exec('perl '.substr($0, 0, -7).'FHEM/00_SONOS.pm '.$port.' '.$verboselevel.' '.(($attr{global}{mseclog}) ? '1' : '0'));
			exit(0);
		}
	} else {
		$socket->sockopt(SO_LINGER, pack("ii", 1, 0));
		
		# Antwort vom Client weglesen...
		my $answer;
		$socket->recv($answer, 50);
		
		# Hiermit wird eine etwaig bestehende Thread-Struktur beendet und diese Verbindung selbst geschlossen...
		eval{
			$socket->send("disconnect\n", 0);
			$socket->shutdown(2);
			$socket->close();
		};
	}
	
	return undef;
}

########################################################################################
#
# SONOS_InitClientProcessLater - Initializes the client-process at a later time
#
# Parameter hash = The device-hash
#
########################################################################################
sub SONOS_InitClientProcessLater($) {
	my ($hash) = @_;
	
	# Begrüßung weglesen...
	my $answer = DevIo_SimpleRead($hash);
	
	# Verbindung aufbauen...
	InternalTimer(gettimeofday() + 1, 'SONOS_InitClientProcess', $hash, 0);
	
	return undef;
}

########################################################################################
#
# SONOS_InitClientProcess - Initializes the client-process
#
# Parameter hash = The device-hash
#
########################################################################################
sub SONOS_InitClientProcess($) {
	my ($hash) = @_;
	
	my @playerudn = ();
	my @playername = ();
	foreach my $fhem_dev (sort keys %main::defs) { 
		next if($main::defs{$fhem_dev}{TYPE} ne 'SONOSPLAYER');
		
		push @playerudn, $main::defs{$fhem_dev}{UDN};
		push @playername, $main::defs{$fhem_dev}{NAME};
	}
	
	# Grundsätzliche Informationen bzgl. der konfigurierten Player übertragen...
	my $setDataString = 'SetData:'.$hash->{NAME}.':'.AttrVal($hash->{NAME}, 'verbose', '3').':'.AttrVal($hash->{NAME}, 'pingType', 'none').':'.join(',', @playername).':'.join(',', @playerudn);
	SONOS_Log undef, 5, $setDataString;
	DevIo_SimpleWrite($hash, $setDataString."\n", 0);
	
	# Gemeldete Attribute, Definitionen und Readings übertragen...
	foreach my $fhem_dev (sort keys %main::defs) { 
		if (($main::defs{$fhem_dev}{TYPE} eq 'SONOSPLAYER') || ($main::defs{$fhem_dev}{TYPE} eq 'SONOS')) {
			# Den Namen des Devices ermitteln (normalerweise die UDN, bis auf das zentrale Sonos-Device)
			my $dataName;
			if ($main::defs{$fhem_dev}{TYPE} eq 'SONOS') {
				$dataName = 'SONOS';
			} else {
				$dataName = $main::defs{$fhem_dev}{UDN};
			}
			
			# Variable für die gesammelten Informationen, die übertragen werden sollen...
			my %valueList = ();
			
			# Attribute
			foreach my $key (keys %{$main::attr{$fhem_dev}}) {
				if (SONOS_posInList($key, @SONOS_PossibleAttributes) != -1) {
					$valueList{$key} = $main::attr{$fhem_dev}{$key};
				}
			}
			
			# Definitionen
			foreach my $key (keys %{$main::defs{$fhem_dev}}) {
				if (SONOS_posInList($key, @SONOS_PossibleDefinitions) != -1) {
					$valueList{$key} = $main::defs{$fhem_dev}{$key};
				}
			}
			
			# Readings
			foreach my $key (keys %{$main::defs{$fhem_dev}{READINGS}}) {
				if (SONOS_posInList($key, @SONOS_PossibleReadings) != -1) {
					$valueList{$key} = $main::defs{$fhem_dev}{READINGS}{$key}{VAL};
				}
			}
			
			# Werte in Text-Array umwandeln und dabei prüfen, ob überhaupt ein Wert gesetzt werden soll...
			my @values = ();
			foreach my $key (keys %valueList) {
				if (defined($key) && defined($valueList{$key})) {
					push @values, $key.'='.uri_escape($valueList{$key});
				}
			}
			
			# Übertragen...
			SONOS_Log undef, 5, 'SetValues:'.$dataName.':'.join('|', @values);
			DevIo_SimpleWrite($hash, 'SetValues:'.$dataName.':'.join('|', @values)."\n", 0);
		}
	}
	
	# Alle Informationen sind drüben, dann Threads dort drüben starten
	DevIo_SimpleWrite($hash, "StartThread\n", 0);
	
	# Interner Timer für die Überprüfung der Verbindung zum Client (nicht verwechseln mit dem IsAlive-Timer, der die Existenz eines Sonosplayers überprüft)
	InternalTimer(gettimeofday() + ($hash->{INTERVAL} * 2), 'SONOS_IsSubprocessAliveChecker', $hash, 0);
	
	return undef;
}

########################################################################################
#
# SONOS_IsSubprocessAliveChecker - Internal checking routine for isAlive of the subprocess
# 
########################################################################################
sub SONOS_IsSubprocessAliveChecker() {
	my ($hash) = @_;
	
	my $answer;
	my $socket = new IO::Socket::INET(PeerAddr => $hash->{DeviceName}, Proto => 'tcp');
	if ($socket) {
		$socket->sockopt(SO_LINGER, pack("ii", 1, 0));
		
		$socket->recv($answer, 500);
		
		$socket->send("hello\n", 0);
		$socket->recv($answer, 500);
		
		$socket->send("goaway\n", 0);
		
		$socket->shutdown(2);
		$socket->close();
	}
	
	if (defined($answer)) {
		$answer =~ s/[\r\n]//g;
	}
	
	if (!defined($answer) || ($answer ne 'OK')) {
		SONOS_Log undef, 0, 'No Answer from Subprocess. Restart Sonos-Subprocess...';
		
		# Verbindung beenden, damit der SubProzess die Chance hat neu initialisiert zu werden...
		RemoveInternalTimer($hash);
		DevIo_SimpleWrite($hash, "disconnect\n", 0);
		DevIo_CloseDev($hash);
		
		# Neu anstarten...
		SONOS_StartClientProcessIfNeccessary($hash->{DeviceName}) if ($SONOS_StartedOwnUPnPServer);
		InternalTimer(gettimeofday() + $hash->{WAITTIME}, 'SONOS_DelayOpenDev', $hash, 0);
	} elsif (defined($answer) && ($answer eq 'OK')) {
		SONOS_Log undef, 4, 'Got correct Answer from Subprocess...';
		
		InternalTimer(gettimeofday() + $hash->{INTERVAL}, 'SONOS_IsSubprocessAliveChecker', $hash, 0);
	}
}

########################################################################################
#
# SONOS_DoTriggerInternal - Internal working routine for DoTrigger and PeekTriggerQueueInLocalThread 
# 
########################################################################################
sub SONOS_DoTriggerInternal($$) {
	my ($triggerType, @lines) = @_;

	# Eval Kommandos ausführen
	my %doTriggerHashParam;
	my @doTriggerArrayParam;
	my $doTriggerScalarParam;
	foreach my $line (@lines) {
		my $reftype = reftype $line;
		
		if (!defined $reftype) {
			SONOS_Log undef, 5, $triggerType.'Trigger()-Line: '.$line; 

			eval $line;
			if ($@) {
				SONOS_Log undef, 2, 'Error during '.$triggerType.'Trigger: '.$@.' - Trying to execute \''.$line.'\'';
			}
			
			undef(%doTriggerHashParam);
			undef(@doTriggerArrayParam);
			undef($doTriggerScalarParam);
		} elsif($reftype eq 'HASH') {
			%doTriggerHashParam = %{$line};
			SONOS_Log undef, 5, $triggerType.'Trigger()-doTriggerHashParam: '.SONOS_Stringify(\%doTriggerHashParam);
		} elsif($reftype eq 'ARRAY') {
			@doTriggerArrayParam = @{$line};
			SONOS_Log undef, 5, $triggerType.'Trigger()-doTriggerArrayParam: '.SONOS_Stringify(\@doTriggerArrayParam);
		} elsif($reftype eq 'SCALAR') {
			$doTriggerScalarParam = ${$line};
			SONOS_Log undef, 5, $triggerType.'Trigger()-doTriggerScalarParam: '.SONOS_Stringify(\$doTriggerScalarParam);
		}
	}
}

########################################################################################
#
#  SONOS_Get - Implements GetFn function 
#
#  Parameter hash = hash of the master 
#						 a = argument array
#
########################################################################################
sub SONOS_Get($@) {
	my ($hash, @a) = @_;
	
	my $reading = $a[1];
	my $name = $hash->{NAME};
	
	# check argument
	return "SONOS: Get with unknown argument $a[1], choose one of ".join(",", sort keys %gets) if(!defined($gets{$reading}));
	
	# some argument needs parameter(s), some not
	return "SONOS: $a[1] needs parameter(s): ".$gets{$a[1]} if (scalar(split(',', $gets{$a[1]})) > scalar(@a) - 2);
	
	# getter
	if (lc($reading) eq 'groups') {
		return SONOS_ConvertZoneGroupStateToString(SONOS_ConvertZoneGroupState(ReadingsVal($name, 'ZoneGroupState', '')));
	} 
  
	return undef;
}

########################################################################################
#
#  SONOS_ConvertZoneGroupState - Retrieves the Groupstate in an array (Elements are UDNs)
#
########################################################################################
sub SONOS_ConvertZoneGroupState($) {
	my ($zoneGroupState) = @_;
	
	my @groups = ();
	while ($zoneGroupState =~ m/<ZoneGroup.*?Coordinator="(.*?)".*?>(.*?)<\/ZoneGroup>/gi) {
		my @group = ($1.'_MR');
		my $groupMember = $2;

		while ($groupMember =~ m/<ZoneGroupMember.*?UUID="(.*?)"(.*?)\/>/gi) {
			my $udn = $1;
			my $string = $2;
			push @group, $udn.'_MR' if (!($string =~ m/IsZoneBridge="."/) && !SONOS_isInList($udn.'_MR', @group));
			
			# Etwaig von vorher enthaltene Bridges wieder entfernen (wenn sie bereits als Koordinator eingesetzt wurde)
			if ($string =~ m/IsZoneBridge="."/) {
				for(my $i = 0; $i <= $#group; $i++) {
					delete $group[$i] if ($group[$i] eq $udn.'_MR');
				}
			}
		}
		
		# Die Abspielgruppe hinzufügen, wenn sie nicht leer ist (kann bei Bridges passieren)
		push @groups, \@group if ($#group >= 0);
	}
	
	return @groups;
}

########################################################################################
#
#  SONOS_ConvertZoneGroupStateToString - Converts the GroupState into a String
#
########################################################################################
sub SONOS_ConvertZoneGroupStateToString($) {
	my (@groups) = @_;
	
	# UDNs durch Devicenamen ersetzen und dabei gleich das Ergebnis zusammenbauen
	my $result = '';
	foreach my $gelem (@groups) {
		$result .= '[';
		foreach my $elem (@{$gelem}) {
			$elem = SONOS_getSonosPlayerByUDN($elem)->{NAME};
		}
		$result .= join(', ', @{$gelem}).'], ';
	}

	return substr($result, 0, -2);
}

########################################################################################
#
#  SONOS_Set - Implements SetFn function
# 
#  Parameter hash
#						 a = argument array
#
########################################################################################
sub SONOS_Set($@) {
	my ($hash, @a) = @_;
  
	# %setCopy enthält eine Kopie von %sets, da für eine ?-Anfrage u.U. ein Slider zurückgegeben werden muss...
	my %setcopy;
	if (AttrVal($hash, 'generateVolumeSlider', 1) == 1) {
		foreach my $key (keys %sets) {
			my $oldkey = $key;
			$key = $key.':slider,0,1,100' if ($key eq 'Volume');
			$key = $key.':slider,-100,1,100' if ($key eq 'Balance');
		
			$setcopy{$key} = $sets{$oldkey};
		}
	} else {
		%setcopy = %sets;
	}

	# for the ?-selector: which values are possible
	return join(" ", sort keys %setcopy) if($a[1] eq '?');
  
	# check argument
	return "SONOS: Set with unknown argument $a[1], choose one of ".join(",", sort keys %sets) if(!defined($sets{$a[1]}));
  
	# some argument needs parameter(s), some not
	return "SONOS: $a[1] needs parameter(s): ".$sets{$a[1]} if (scalar(split(',', $sets{$a[1]})) > scalar(@a) - 2);
      
	# define vars
	my $key = $a[1];
	my $value = $a[2];
	my $value2 = $a[3];
	my $name = $hash->{NAME};
	
	# setter
	if (lc($key) eq 'groups') {
		# [Sonos_Jim], [Sonos_Wohnzimmer, Sonos_Schlafzimmer] => [] Liste, Der erste Eintrag soll Koordinator sein
		# Idee: [Sonos_Jim], {Sonos_Wohnzimmer, Sonos_Schlafzimmer} => {} Menge, bedeutet beliebiger Koordinator
		
		my $text = '';
		for(my $i = 2; $i < @a; $i++) {
			$text .= ' '.$a[$i];
		}
		$text =~ s/ //g;
		
		# Aktuellen Zustand holen
		my @current;
		my $current = SONOS_Get($hash, qw($hash->{NAME} Groups));
		$current =~ s/ //g;
		while ($current =~ m/(\[.*?\])/ig) {
			my @tmp = split(/,/, substr($1, 1, -1));
			push @current, \@tmp;
		}

		# Gewünschten Zustand holen
		my @desiredList;
		my @desiredCrowd;
		while ($text =~ m/([\[\{].*?[\}\]])/ig) {
			my @tmp = split(/,/, substr($1, 1, -1));
			if (substr($1, 0, 1) eq '{') {
				push @desiredCrowd, \@tmp;
			} else {
				push @desiredList, \@tmp;
			}
		}
		SONOS_Log undef, 5, "Desired-Crowd: ".Dumper(\@desiredCrowd);
		SONOS_Log undef, 5, "Desired-List: ".Dumper(\@desiredList);
		
		# Erstmal die Listen sicherstellen
		foreach my $dElem (@desiredList) {
			my @list = @{$dElem};
			for(my $i = 0; $i <= $#list; $i++) { # Die jeweilige Desired-List
				my $elem = $list[$i];
				my $elemHash = SONOS_getDeviceDefHash($elem);
				my $reftype  = reftype $elemHash;
				if (!defined($reftype) || $reftype ne 'HASH') {
					SONOS_Log undef, 5, "Hash not found for Device '$elem'. Is it gone away or not known?";
					return undef;
				}
				
				# Das Element soll ein Gruppenkoordinator sein
				if ($i == 0) {
					my $cPos = -1;
					foreach my $cElem (@current) {
						$cPos = SONOS_posInList($elem, @{$cElem});
						last if ($cPos != -1);
					}
					
					# Ist es aber nicht... also erstmal dazu machen
					if ($cPos != 0) {
						SONOS_DoWork($elemHash->{UDN}, 'makeStandaloneGroup');
						usleep(250_000);
					}
				} else {
					# Alle weiteren dazufügen
					my $cHash = SONOS_getDeviceDefHash($list[0]);
					SONOS_DoWork($cHash->{UDN}, 'addMember', $elemHash->{UDN});
					usleep(250_000);
				}
			}
		}
		
		# Jetzt noch die Mengen sicherstellen
		# Dazu aktuellen Zustand nochmal holen
		#@current = ();
		#$current = SONOS_Get($hash, qw($hash->{NAME} Groups));
		#$current =~ s/ //g;
		#while ($current =~ m/(\[.*?\])/ig) {
		#	my @tmp = split(/,/, substr($1, 1, -1));
		#	push @current, \@tmp;
		#}
		#SONOS_Log undef, 5, "Current after List: ".Dumper(\@current);
		
	} elsif (lc($key) =~ m/(Stop|Pause)All/i) {
		my $commandType = $1;
		
		# Aktuellen Zustand holen
		my @current;
		my $current = SONOS_Get($hash, qw($hash->{NAME} Groups));
		$current =~ s/ //g;
		while ($current =~ m/(\[.*?\])/ig) {
			my @tmp = split(/,/, substr($1, 1, -1));
			push @current, \@tmp;
		}
		
		# Alle Gruppenkoordinatoren zum Stoppen/Pausieren aufrufen
		foreach my $cElem (@current) {
			my @currentElem = @{$cElem};
			SONOS_DoWork(SONOS_getDeviceDefHash($currentElem[0])->{UDN}, lc($commandType), 0);
		}
	} else {
		return 'Not implemented yet!';
	}
  
	return (undef, 1);
}

########################################################################################
#
#  SONOS_DoWork - Communicates with the forked Part via Telnet and over there via ComObjectTransportQueue
#
# Parameter deviceName = Devicename of the SonosPlayer
#			method = Name der "Methode" die im Thread-Context ausgeführt werden soll
#			params = Parameter for the method
#
########################################################################################
sub SONOS_DoWork($@) {
	my ($udn, $method, @params) = @_;
	
	if (!defined($udn)) {
		SONOS_Log undef, 0, "ERROR in DoWork: '$method' -> UDN is undefined - ".Dumper(\@params);
	}
	
	# Etwaige optionale Parameter, die sonst undefined wären, löschen
	for(my $i = 0; $i <= $#params; $i++) {
		if (!defined($params[$i])) {
			delete($params[$i]);
		}
	}
	
	my $hash = SONOS_getDeviceDefHash(undef);
	
	DevIo_SimpleWrite($hash, 'DoWork:'.$udn.':'.$method.':'.join(',', @params)."\r\n", 0);
		
	return undef;
}

########################################################################################
#
#  SONOS_Discover - Discover SonosPlayer, 
#                   indirectly autocreate devices if not already present (via callback)
#
########################################################################################
sub SONOS_Discover() {
	SONOS_Log undef, 3, 'UPnP-Thread gestartet.';
	
	$SIG{'PIPE'} = 'IGNORE';
	$SIG{'CHLD'} = 'IGNORE';
  
	# Thread 'cancellation' signal handler
	$SIG{'INT'} = sub { 
		# Sendeliste leeren
		while ($SONOS_Client_SendQueue->pending()) {
			$SONOS_Client_SendQueue->dequeue();
		}
		
		# Empfängerliste leeren
		while ($SONOS_ComObjectTransportQueue->pending()) {
			$SONOS_ComObjectTransportQueue->dequeue();
		}
		
		# UPnP-Listener beenden
		SONOS_StopControlPoint();
		
		SONOS_Log undef, 3, 'Controlpoint-Listener wurde beendet.';
		return 1;
	};
	
	# Thread Signal Handler for doing some work in this thread 'environment'
	$SIG{'HUP'} = sub {
		while ($SONOS_ComObjectTransportQueue->pending()) {
			my $data = $SONOS_ComObjectTransportQueue->peek();
			my $workType = $data->{WorkType};
			my $udn = $data->{UDN};
			my @params = @{$data->{Params}};
			
			eval {
				if ($workType eq 'setVerbose') {
					$SONOS_Client_LogLevel = $params[0];
					SONOS_Log undef, 0, "Setting LogLevel to new value: $SONOS_Client_LogLevel";
				} elsif ($workType eq 'setName') {
					my $value1 = SONOS_Utf8ToLatin1($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_DevicePropertiesProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_DevicePropertiesProxy{$udn}->SetZoneAttributes($value1, '', '')));
					}
				} elsif ($workType eq 'setIcon') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_DevicePropertiesProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_DevicePropertiesProxy{$udn}->SetZoneAttributes('', 'x-rincon-roomicon:'.$value1, '')));
					}
				} elsif ($workType eq 'getCurrentTrackPosition') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('RelTime'));
					}
				} elsif ($workType eq 'setCurrentTrackPosition') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						$SONOS_AVTransportControlProxy{$udn}->Seek(0, 'REL_TIME', $value1);
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('RelTime'));
					}
				} elsif ($workType eq 'reportUnresponsiveDevice') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_ZoneGroupTopologyProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_ZoneGroupTopologyProxy{$udn}->ReportUnresponsiveDevice($value1, 'VerifyThenRemoveSystemwide')));
					}
				} elsif ($workType eq 'setGroupVolume') {
					my $value1 = $params[0];
					my $value2 = $params[1];
					
					# Wenn ein fixer Wert für alle Gruppenmitglieder gleich gesetzt werden soll...
					if (defined($value2) && lc($value2) eq 'fixed') {
						
					} else {
						if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
							$SONOS_GroupRenderingControlProxy{$udn}->SetGroupVolume(0, $value1);
						
							# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_GroupRenderingControlProxy{$udn}->GetGroupVolume(0)->getValue('CurrentVolume'));
						}
					}
				} elsif ($workType eq 'setSnapshotGroupVolume') {
					if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_GroupRenderingControlProxy{$udn}->SnapshotGroupVolume(0)));
					}
				} elsif ($workType eq 'setVolume') {
					my $value1 = $params[0];
					my $ramptype = $params[1];
								
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						if (defined($ramptype)) {
							if ($ramptype == 1) {
								$ramptype = 'SLEEP_TIMER_RAMP_TYPE';
							} elsif ($ramptype == 2) {
								$ramptype = 'AUTOPLAY_RAMP_TYPE';
							} elsif ($ramptype == 3) {
								$ramptype = 'ALARM_RAMP_TYPE';
							}
							my $ramptime = $SONOS_RenderingControlProxy{$udn}->RampToVolume(0, 'Master', $ramptype, $value1, 0, '')->getValue('RampTime');
							
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Ramp to '.$value1.' with Type '.$params[1].' started');
						} else {
							$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'Master', $value1);
						
							# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume'));
						}
					}
				} elsif ($workType eq 'setRelativeGroupVolume') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_GroupRenderingControlProxy{$udn}->SetRelativeGroupVolume(0, $value1)->getValue('NewVolume'));
					}
				} elsif ($workType eq 'setRelativeVolume') {
					my $value1 = $params[0];
					my $ramptype = $params[1];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						if (defined($ramptype)) {
							if ($ramptype == 1) {
								$ramptype = 'SLEEP_TIMER_RAMP_TYPE';
							} elsif ($ramptype == 2) {
								$ramptype = 'AUTOPLAY_RAMP_TYPE';
							} elsif ($ramptype == 3) {
								$ramptype = 'ALARM_RAMP_TYPE';
							}
							
							# Wenn eine Prozentangabe übergeben wurde, dann die wirkliche Ziellautstärke ermitteln/berechnen
							if ($value1 =~ m/([+-])(\d+)\%/) {
								my $currentValue = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume');
								$value1 = $currentValue + eval{ $1.($currentValue * ($2 / 100)) };
							} else {
								# Hier aus der Relativangabe eine Absolutangabe für den Aufruf von RampToVolume machen
								$value1 = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume') + $value1;
							}
							$SONOS_RenderingControlProxy{$udn}->RampToVolume(0, 'Master', $ramptype, $value1, 0, '');
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Ramp to '.$value1.' with Type '.$params[1].' started');
						} else {
							# Wenn eine Prozentangabe übergeben wurde, dann die wirkliche Ziellautstärke ermitteln/berechnen
							if ($value1 =~ m/([+-])(\d+)\%/) {
								my $currentValue = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume');
								$value1 = $currentValue + eval{ $1.($currentValue * ($2 / 100)) };
								
								$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'Master', $value1);
							
								# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume'));
							} else {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_RenderingControlProxy{$udn}->SetRelativeVolume(0, 'Master', $value1)->getValue('NewVolume'));
							}
						}
					}
				} elsif ($workType eq 'setBalance') {
					my $value1 = $params[0];
					
					# Balancewert auf die beiden Lautstärkeseiten aufteilen...
					my $volumeLeft = 100;
					my $volumeRight = 100;
					if ($value1 < 0) {
						$volumeRight = 100 + $value1;
					} else {
						$volumeLeft = 100 - $value1;
					}
								
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'LF', $volumeLeft);
						$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'RF', $volumeRight);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						$volumeLeft = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'LF')->getValue('CurrentVolume');
						$volumeRight = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'RF')->getValue('CurrentVolume');
						
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.((-$volumeLeft) + $volumeRight));
					}
				} elsif ($workType eq 'setLoudness') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						$SONOS_RenderingControlProxy{$udn}->SetLoudness(0, 'Master', SONOS_ConvertWordToNum($value1));
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_RenderingControlProxy{$udn}->GetLoudness(0, 'Master')->getValue('CurrentLoudness')));
					}
				} elsif ($workType eq 'setBass') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						$SONOS_RenderingControlProxy{$udn}->SetBass(0, $value1);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_RenderingControlProxy{$udn}->GetBass(0)->getValue('CurrentBass'));
					}
				} elsif ($workType eq 'setTreble') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						$SONOS_RenderingControlProxy{$udn}->SetTreble(0, $value1);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_RenderingControlProxy{$udn}->GetTreble(0)->getValue('CurrentTreble'));
					}
				} elsif ($workType eq 'setMute') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						$SONOS_RenderingControlProxy{$udn}->SetMute(0, 'Master', SONOS_ConvertWordToNum($value1));
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_RenderingControlProxy{$udn}->GetMute(0, 'Master')->getValue('CurrentMute')));
					}
				} elsif ($workType eq 'setMuteT') {
					my $value1 = 'off';
					if (SONOS_CheckProxyObject($udn, $SONOS_RenderingControlProxy{$udn})) {
						if ($SONOS_RenderingControlProxy{$udn}->GetMute(0, 'Master')->getValue('CurrentMute') == 0) {
							$value1 = 'on';
						} else {
							$value1 = 'off';
						}
						
						$SONOS_RenderingControlProxy{$udn}->SetMute(0, 'Master', SONOS_ConvertWordToNum($value1));
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_RenderingControlProxy{$udn}->GetMute(0, 'Master')->getValue('CurrentMute')));
					}
				} elsif ($workType eq 'setGroupMute') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
						$SONOS_GroupRenderingControlProxy{$udn}->SetGroupMute(0, SONOS_ConvertWordToNum($value1));
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_GroupRenderingControlProxy{$udn}->GetGroupMute(0)->getValue('CurrentMute')));
					}
				} elsif ($workType eq 'setShuffle') {
					my $value1 = SONOS_ConvertWordToNum($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						my $result = $SONOS_AVTransportControlProxy{$udn}->GetTransportSettings(0)->getValue('PlayMode');
						
						my $shuffle = $result eq 'SHUFFLE' || $result eq 'SHUFFLE_NOREPEAT';
						my $repeat = $result eq 'SHUFFLE' || $result eq 'REPEAT_ALL';
						
						my $newMode = 'NORMAL';
						$newMode = 'SHUFFLE' if ($value1 && $repeat);
						$newMode = 'SHUFFLE_NOREPEAT' if ($value1 && !$repeat);
						$newMode = 'REPEAT_ALL' if (!$value1 && $repeat);
					
						$SONOS_AVTransportControlProxy{$udn}->SetPlayMode(0, $newMode);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						$result = $SONOS_AVTransportControlProxy{$udn}->GetTransportSettings(0)->getValue('PlayMode');
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($result eq 'SHUFFLE' || $result eq 'SHUFFLE_NOREPEAT'));
					}
				} elsif ($workType eq 'setRepeat') {
					my $value1 = SONOS_ConvertWordToNum($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						my $result = $SONOS_AVTransportControlProxy{$udn}->GetTransportSettings(0)->getValue('PlayMode');
						
						my $shuffle = $result eq 'SHUFFLE' || $result eq 'SHUFFLE_NOREPEAT';
						my $repeat = $result eq 'SHUFFLE' || $result eq 'REPEAT_ALL';
						
						my $newMode = 'NORMAL';
						$newMode = 'SHUFFLE' if ($value1 && $shuffle);
						$newMode = 'SHUFFLE_NOREPEAT' if (!$value1 && $shuffle);
						$newMode = 'REPEAT_ALL' if ($value1 && !$shuffle);
					
						$SONOS_AVTransportControlProxy{$udn}->SetPlayMode(0, $newMode);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						$result = $SONOS_AVTransportControlProxy{$udn}->GetTransportSettings(0)->getValue('PlayMode');
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($result eq 'SHUFFLE' || $result eq 'REPEAT_ALL'));
					}
				} elsif ($workType eq 'setCrossfadeMode') {
					my $value1 = SONOS_ConvertWordToNum($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						$SONOS_AVTransportControlProxy{$udn}->SetCrossfadeMode(0, $value1);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_AVTransportControlProxy{$udn}->GetCrossfadeMode(0)->getValue('CrossfadeMode')));
					}
				} elsif ($workType eq 'setLEDState') {
					my $value1 = (SONOS_ConvertWordToNum($params[0])) ? 'On' : 'Off';
					
					if (SONOS_CheckProxyObject($udn, $SONOS_DevicePropertiesProxy{$udn})) {
						$SONOS_DevicePropertiesProxy{$udn}->SetLEDState($value1);
					
						# Wert wieder abholen, um das wahre Ergebnis anzeigen zu können
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_ConvertNumToWord($SONOS_DevicePropertiesProxy{$udn}->GetLEDState()->getValue('CurrentLEDState')));
					}
				} elsif ($workType eq 'play') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Play(0, 1)));
					}
				} elsif ($workType eq 'stop') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Stop(0)));
					}
				} elsif ($workType eq 'pause') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Pause(0)));
					}
				} elsif ($workType eq 'previous') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Previous(0)));
					}
				} elsif ($workType eq 'next') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Next(0)));
					}
				} elsif ($workType eq 'setTrack') {
					my $value1 = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn}) && SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						# Abspielliste aktivieren?
						my $currentURI = $SONOS_AVTransportControlProxy{$udn}->GetMediaInfo(0)->getValue('CurrentURI');
						if ($currentURI !~ m/x-rincon-queue:/) {
							my $queueMetadata = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '');
							my $result = $SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, SONOS_GetTagData('res', $queueMetadata->getValue('Result')), '');
						}
						
						if (lc($value1) eq 'random') {
							$SONOS_AVTransportControlProxy{$udn}->Seek(0, 'TRACK_NR', int(rand($SONOS_AVTransportControlProxy{$udn}->GetMediaInfo(0)->getValue('NrTracks'))));
						} else {
							$SONOS_AVTransportControlProxy{$udn}->Seek(0, 'TRACK_NR', $value1);
						}
	
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('Track'));
					}
				} elsif ($workType eq 'setCurrentPlaylist') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						# Abspielliste aktivieren?
						my $currentURI = $SONOS_AVTransportControlProxy{$udn}->GetMediaInfo(0)->getValue('CurrentURI');
						if ($currentURI !~ m/x-rincon-queue:/) {
							my $queueMetadata = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '');
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, SONOS_GetTagData('res', $queueMetadata->getValue('Result')), '')));
						} else {
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Not neccessary!');
						}
					}
				} elsif ($workType eq 'getPlaylists') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('SQ:', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<container id="(SQ:\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<\/container>/ig) {
							$resultHash{$1} = $2;
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': "'.join('","', sort values %resultHash).'"');
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'getPlaylistsWithCovers') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('SQ:', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<container id="(SQ:\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<res.*?>(.*?)<\/res>.*?<\/container>/ig) {
							$resultHash{$1}->{Title} = $2;
							$resultHash{$1}->{Cover} = SONOS_MakeCoverURL($udn, $3);
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.Dumper(\%resultHash));
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'getFavourites') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('FV:2', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<item id="(FV:2\/\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<\/item>/ig) {
							$resultHash{$1} = $2;
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': "'.join('","', sort values %resultHash).'"');
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'getFavouritesWithCovers') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('FV:2', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<item id="(FV:2\/\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<res.*?>(.*?)<\/res>.*?<\/item>/ig) {
							$resultHash{$1}->{Title} = $2;
							$resultHash{$1}->{Cover} = SONOS_MakeCoverURL($udn, $3);
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.Dumper(\%resultHash));
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'getRadios') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('R:0/0', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<item id="(R:0\/0\/\d+)".*?><dc:title>(.*?)<\/dc:title>.*?<res.*?>(.*?)<\/res>.*?<\/item>/ig) {
							$resultHash{$1} = $2;
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': "'.join('","', sort values %resultHash).'"');
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'getRadiosWithCovers') {
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('R:0/0', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
					
						my %resultHash;
						while ($tmp =~ m/<item id="(R:0\/0\/\d+)".*?><dc:title>(.*?)<\/dc:title>.*?<res.*?>(.*?)<\/res>.*?<\/item>/ig) {
							$resultHash{$1}->{Title} = $2;
							$resultHash{$1}->{Cover} = SONOS_MakeCoverURL($udn, $3);
						}
						
						$Data::Dumper::Indent = 0;
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.Dumper(\%resultHash));
						$Data::Dumper::Indent = 2;
					}
				} elsif ($workType eq 'loadRadio') {
					my $radioName = uri_unescape($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('R:0/0', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
						
						SONOS_Log $udn, 5, 'LoadRadio BrowseResult: '.$tmp;
					
						my %resultHash;
						while ($tmp =~ m/(<item id="(R:0\/0\/\d+)".*?>)<dc:title>(.*?)<\/dc:title>.*?(<upnp:class>.*?<\/upnp:class>).*?<res.*?>(.*?)<\/res>.*?<\/item>/ig) {
							$resultHash{$3}{TITLE} = $3;
							$resultHash{$3}{RES} = decode_entities($5);
							$resultHash{$3}{METADATA} = $SONOS_DIDLHeader.$1.'<dc:title>'.$3.'</dc:title>'.$4.'<desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON65031_</desc></item>'.$SONOS_DIDLFooter;
						}
						
						if (!$resultHash{$radioName}) {
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Radio "'.$radioName.'" not found. Choose one of: "'.join('","', sort keys %resultHash).'"');
							return;
						}
					
						if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
							SONOS_Log $udn, 5, 'LoadRadio SetAVTransport-Res: "'.$resultHash{$radioName}{RES}.'", -Meta: "'.$resultHash{$radioName}{METADATA}.'"';
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, $resultHash{$radioName}{RES}, $resultHash{$radioName}{METADATA})));
						}
					}
				} elsif ($workType eq 'startFavourite') {
					my $favouriteName = uri_unescape($params[0]);
					my $nostart = 0;
					if (defined($params[1]) && lc($params[1]) eq 'nostart') {
						$nostart = 1;
					}
					
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('FV:2', 'BrowseDirectChildren', '', 0, 0, '');
						my $tmp = $result->getValue('Result');
						
						SONOS_Log $udn, 5, 'StartFavourite BrowseResult: '.$tmp;
					
						my %resultHash;
						while ($tmp =~ m/(<item id="(FV:2\/\d+)".*?>)<dc:title>(.*?)<\/dc:title>.*?<res.*?>(.*?)<\/res>.*?<r:resMD>(.*?)<\/r:resMD>.*?<\/item>/ig) {
							$resultHash{$3}{TITLE} = $3;
							$resultHash{$3}{RES} = decode_entities($4);
							$resultHash{$3}{METADATA} = decode_entities($5);
						}
						
						if (!$resultHash{$favouriteName}) {
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Favourite "'.$favouriteName.'" not found. Choose one of: "'.join('","', sort keys %resultHash).'"');
							return;
						}
						
						if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
							# Entscheiden, ob eine Abspielliste geladen und gestartet werden soll, oder etwas direkt abgespielt werden kann
							if ($resultHash{$favouriteName}{METADATA} =~ m/<upnp:class>object.container.playlistContainer<\/upnp:class>/i) {
	
								SONOS_Log $udn, 5, 'StartFavourite AddToQueue-Res: "'.$resultHash{$favouriteName}{RES}.'", -Meta: "'.$resultHash{$favouriteName}{METADATA}.'"';
								
								# Queue leeren
								$SONOS_AVTransportControlProxy{$udn}->RemoveAllTracksFromQueue(0);
								
								# Queue wieder füllen
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->AddURIToQueue(0, $resultHash{$favouriteName}{RES}, $resultHash{$favouriteName}{METADATA}, 0, 1)));
								
								# Queue aktivieren
								$SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, SONOS_GetTagData('res', $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '')->getValue('Result')), '');
							} else {
								SONOS_Log $udn, 5, 'StartFavourite SetAVTransport-Res: "'.$resultHash{$favouriteName}{RES}.'", -Meta: "'.$resultHash{$favouriteName}{METADATA}.'"';
								
								# Stück aktivieren
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, $resultHash{$favouriteName}{RES}, $resultHash{$favouriteName}{METADATA})));
							}
							
							# Abspielen starten, wenn nicht absichtlich verhindert
							$SONOS_AVTransportControlProxy{$udn}->Play(0, 1) if (!$nostart);
						}
					}
				} elsif ($workType eq 'loadPlaylist') {
					my $answer = '';
					my $playlistName = uri_unescape($params[0]);
					my $overwrite = $params[1];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn}) && SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						# Queue vorher leeren?
						if ($overwrite) {
							$SONOS_AVTransportControlProxy{$udn}->RemoveAllTracksFromQueue();
							$answer .= 'Queue successfully emptied. ';
						}
						
						my $currentInsertPos = $SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('Track') + 1;
						
						if ($playlistName =~ /^:m3ufile:(.*)/) {
							my @URIs = ();
							my @Metas = ();
							
							# Versuche die Datei zu öffnen
							if (!open(FILE, '<'.$1)) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Error during opening file "'.$1.'": '.$!); 
								return;
							};
							
							binmode(FILE, ':encoding(utf-8)');
							while (<FILE>) {
								if ($_ =~ m/^ *([^#].*) *\n/) {
									next if ($1 eq '');
									
									my ($res, $meta) = SONOS_CreateURIMeta(SONOS_ExpandURIForQueueing($1));
									
									push(@URIs, $res);
									push(@Metas, $meta);
								}
							}
							close FILE;
							
							my $sliceSize = 16;
							my $result;
							my $count = 0;
							
							SONOS_Log $udn, 5, "Start-Adding: Count ".scalar(@URIs)." / $sliceSize";
							
							for my $i (0..int(scalar(@URIs) / $sliceSize)) { # Da hier Nullbasiert vorgegangen wird, brauchen wir die letzte Runde nicht noch hinzuaddieren
								my $startIndex = $i * $sliceSize;
								my $endIndex = $startIndex + $sliceSize - 1;
								$endIndex = SONOS_Min(scalar(@URIs) - 1, $endIndex);
								
								SONOS_Log $udn, 5, "Add($i) von $startIndex bis $endIndex (".($endIndex - $startIndex + 1)." Elemente)";
								SONOS_Log $udn, 5, "Upload($currentInsertPos)-URI: ".join(' ', @URIs[$startIndex..$endIndex]);
								SONOS_Log $udn, 5, "Upload($currentInsertPos)-Meta: ".join(' ', @Metas[$startIndex..$endIndex]);
								
								$result = $SONOS_AVTransportControlProxy{$udn}->AddMultipleURIsToQueue(0, 0, $endIndex - $startIndex + 1, join(' ', @URIs[$startIndex..$endIndex]), join(' ', @Metas[$startIndex..$endIndex]), '', '', $currentInsertPos, 0);
								if (!$result->isSuccessful()) {
									$answer .= 'Adding-Error: '.SONOS_UPnPAnswerMessage($result).' ';
								}
								
								$currentInsertPos += $endIndex - $startIndex + 1;
								$count = $endIndex + 1;
							}
							
							if ($result->isSuccessful()) {
								$answer .= 'Added '.$count.' entries from file "'.$1.'". There are now '.$result->getValue('NewQueueLength').' entries in Queue. ';
							} else {
								$answer .= 'Adding: '.SONOS_UPnPAnswerMessage($result).' ';
							}
						} else {
							my $browseResult = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('SQ:', 'BrowseDirectChildren', '', 0, 0, '');
							my $tmp = $browseResult->getValue('Result');
						
							my %resultHash;
							while ($tmp =~ m/<container id="(SQ:\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<\/container>/ig) {
								$resultHash{$2} = $1;
							}
							
							if (!$resultHash{$playlistName}) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Playlist "'.$playlistName.'" not found. Choose one of: "'.join('","', sort keys %resultHash).'"');
								return;
							}
						
							# Titel laden
							my $playlistData = $SONOS_ContentDirectoryControlProxy{$udn}->Browse($resultHash{$playlistName}, 'BrowseMetadata', '', 0, 0, '');
							my $playlistRes = SONOS_GetTagData('res', $playlistData->getValue('Result'));
						
							# Elemente an die Queue anhängen
							my $result = $SONOS_AVTransportControlProxy{$udn}->AddURIToQueue(0, $playlistRes, '', $currentInsertPos, 0);
							$answer .= $result->getValue('NumTracksAdded').' Elems added. '.$result->getValue('NewQueueLength').' Elems in list now. ';
						}
						
						# Die Liste als aktuelles Abspielstück einstellen
						my $queueMetadata = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '');
						my $result = $SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, SONOS_GetTagData('res', $queueMetadata->getValue('Result')), '');
						$answer .= 'Startlist: '.SONOS_UPnPAnswerMessage($result).'. ';
						
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$answer);
					}
				} elsif ($workType eq 'setAlarm') {
					my $create = $params[0];
					my $id = $params[1];
	
					# Alle folgenden Parameter weglesen und an den letzten Parameter anhängen
					my $values = {};
					my $val = join(',', @params[2..$#params]);
					if ($val ne '') {
						SONOS_Log $udn, 5, 'Val: '.$val;
						$values = \%{eval($val)};
					}
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AlarmClockControlProxy{$udn})) {
						my @idList = split(',', SONOS_Client_Data_Retreive($udn, 'reading', 'AlarmListIDs', ''));
						
						# Die Room-ID immer fest auf den aktuellen Player eintragen. 
						# Hiermit sollte es nicht mehr möglich sein, einen Alarm für einen anderen Player einzutragen. Das kann man auch direkt an dem anderen Player durchführen...
						$values->{RoomUUID} = $1 if ($udn =~ m/(.*?)_MR/i);
						
						if (lc($create) eq 'update') {
							if (!SONOS_isInList($id, @idList)) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(0));
							} else {
								my %alarm = %{eval(SONOS_Client_Data_Retreive($udn, 'reading', 'AlarmList', '{}'))->{$id}};
								
								# Replace old values with the given new ones...
								for my $key (keys %alarm) {
									if (defined($values->{$key})) {
										$alarm{$key} = $values->{$key};
									}
								}
								
								if (!SONOS_CheckAndCorrectAlarmHash(\%alarm)) {
									SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(0));
								} else {
									# Send to Zoneplayer
									SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AlarmClockControlProxy{$udn}->UpdateAlarm($id, $alarm{StartTime}, $alarm{Duration}, $alarm{Recurrence}, $alarm{Enabled}, $alarm{RoomUUID}, $alarm{ProgramURI}, $alarm{ProgramMetaData}, $alarm{PlayMode}, $alarm{Volume}, $alarm{IncludeLinkedZones})));
								}
							}
						} elsif (lc($create) eq 'create') {
							# Check if all parameters are given
							if (!SONOS_CheckAndCorrectAlarmHash($values)) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(0));
							} else {
								# create here on Zoneplayer
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.$SONOS_AlarmClockControlProxy{$udn}->CreateAlarm($values->{StartTime}, $values->{Duration}, $values->{Recurrence}, $values->{Enabled}, $values->{RoomUUID}, $values->{ProgramURI}, $values->{ProgramMetaData}, $values->{PlayMode}, $values->{Volume}, $values->{IncludeLinkedZones})->getValue('AssignedID'));
							}
						} elsif (lc($create) eq 'delete') {
							if (!SONOS_isInList($id, @idList)) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(0).' ID is incorrect!');
							} else {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AlarmClockControlProxy{$udn}->DestroyAlarm($id)));
							}
						} else {
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(0));
						}
					}
				} elsif ($workType eq 'setDailyIndexRefreshTime') {
					my $time = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AlarmClockControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AlarmClockControlProxy{$udn}->SetDailyIndexRefreshTime($time)));
					}
				} elsif ($workType eq 'setSleepTimer') {
					my $time = $params[0];
					
					if ((lc($time) eq 'off') || ($time =~ /0+:0+:0+/)) {
						$time = '';
					}
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->ConfigureSleepTimer(0, $time)));
					}
				} elsif ($workType eq 'addMember') {
					my $memberudn = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$memberudn}) && SONOS_CheckProxyObject($udn, $SONOS_ZoneGroupTopologyProxy{$memberudn})) {
						# Wenn der hinzuzufügende Player Koordinator einer anderen Gruppe ist,
						# dann erst mal ein anderes Gruppenmitglied zum Koordinator machen
						my @zoneTopology = SONOS_ConvertZoneGroupState($SONOS_ZoneGroupTopologyProxy{$memberudn}->GetZoneGroupState()->getValue('ZoneGroupState'));
						
						# Hier fehlt noch die Umstellung der bestehenden Gruppe...
						
						# Sicherstellen, dass der hinzuzufügende Player kein Bestandteil einer Gruppe mehr ist.
						$SONOS_AVTransportControlProxy{$memberudn}->BecomeCoordinatorOfStandaloneGroup(0);
					
						my $coordinatorUDNShort = $1 if ($udn =~ m/(.*)_MR/);
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$memberudn}->SetAVTransportURI(0, 'x-rincon:'.$coordinatorUDNShort, '')));
					}
				} elsif ($workType eq 'removeMember') {
					my $memberudn = $params[0];
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$memberudn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$memberudn}->BecomeCoordinatorOfStandaloneGroup(0)));
					}
				} elsif ($workType eq 'makeStandaloneGroup') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->BecomeCoordinatorOfStandaloneGroup(0)));
					}
				} elsif ($workType eq 'emptyPlaylist') {
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->RemoveAllTracksFromQueue()));
					}
				} elsif ($workType eq 'savePlaylist') {
					my $playlistName = $params[0];
					my $playlistType = $params[1];
					
					$playlistName =~s/ $//g;
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						if ($playlistType eq ':m3ufile:') {
							open (FILE, '>'.$playlistName);
							print FILE "#EXTM3U\n";
							
							my $startIndex = 0;
							my $result;
							my $count = 0;
							do {
								$result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseDirectChildren', '', $startIndex, 0, '');
								my $queueSongdata = $result->getValue('Result');
								
								while ($queueSongdata =~ m/<item.*?>(.*?)<\/item>/gi) {
									my $item = $1;
									my $res = uri_unescape(SONOS_GetURIFromQueueValue(decode_entities($1))) if ($item =~ m/<res.*?>(.*?)<\/res>/i);
									my $artist = decode_entities($1) if ($item =~ m/<dc:creator.*?>(.*?)<\/dc:creator>/i);
									my $title = decode_entities($1) if ($item =~ m/<dc:title.*?>(.*?)<\/dc:title>/i);
									my $time = 0;
									$time = SONOS_GetTimeSeconds($1) if ($item =~ m/.*?duration="(.*?)"/);
									
									# In Datei wegschreiben
									eval {
										print FILE "#EXTINF:$time,($artist) $title\n$res\n";
									};
									$count++;
								}
								
								$startIndex += $result->getValue('NumberReturned');
							} while ($startIndex < $result->getValue('TotalMatches'));
							
							
							close FILE;
							
							SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': New M3U-File "'.$playlistName.'" successfully created with '.$count.' entries!');
						} else {
							my $result = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('SQ:', 'BrowseDirectChildren', '', 0, 0, '');
							my $tmp = $result->getValue('Result');
						
							my %resultHash;
							while ($tmp =~ m/<container id="(SQ:\d+)".*?<dc:title>(.*?)<\/dc:title>.*?<\/container>/ig) {
								$resultHash{$2} = $1;
							}
							
							if ($resultHash{$playlistName}) {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Existing Playlist "'.$playlistName.'" updated: '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->SaveQueue(0, $playlistName, $resultHash{$playlistName})));
							} else {
								SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': New Playlist '.$playlistName.' created: '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->SaveQueue(0, $playlistName, '')));
							}
						}
					}
				} elsif ($workType eq 'createThemeList') {
					# set Player CreateThemeList <SearchField1=SearchValue1>[ <SearchFieldN=SearchValueN>] [ShuffleList] [EmptyList] [Play]
					# set Player CreateThemeList ARTIST=*{1} EmptyList Play
					# set Player CreateThemeList ARTIST=Herbert%20Grönemeyer ShuffleList EmptyList Play
					# set Player CreateThemeList ARTIST=Herbert%20Grönemeyer ALBUM=Zwölf ShuffleList EmptyList Play
					# ARTIST, ALBUMARTIST, ALBUM, GENRE, COMPOSER, TRACKS
					# SearchValue: * -> Beliebiger Wert, {N} -> Anzahl einschränken
					
					my $shuffleList = 0;
					my $emptyList = 0;
					my $play = 0;
					my %searches;
					
					my $answer = '';
					
					#while ($SONOS_ComObjectTransportQueue->pending() > 0) {
					#	my $tmp = $SONOS_ComObjectTransportQueue->dequeue();
					#	
					#	if ($tmp =~ /ShuffleList/i) {
					#		$shuffleList = 1;
					#	} elsif ($tmp =~ /EmptyList/i) {
					#		$emptyList = 1;
					#	} elsif ($tmp =~ /Play/i) {
					#		$play = 1;
					#	} elsif ($tmp =~ /(.*?)=(.*?)/) {
					#		$searches{$1} = $2;
					#	} else {
					#		SONOS_Log $udn, 1, 'Error during parsing of CreateThemeList-Parameter: "'.$tmp.'". Ignoring it!';
					#	}
					#}
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn}) && SONOS_CheckProxyObject($udn, $SONOS_ContentDirectoryControlProxy{$udn})) {
						# EmptyList before adding new elements
						if ($emptyList) {
							$answer .= ', EmptyList: '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->RemoveAllTracksFromQueue());
						}
						
						# Search and Load
						
						# Shuffle retrieved list
						if ($shuffleList) {
							# Do shuffeling here
							
							$answer .= ', ShuffleList: '.SONOS_UPnPAnswerMessage(0);
						}
						
						# Die Liste als aktuelles Abspielstück einstellen
						my $queueMetadata = $SONOS_ContentDirectoryControlProxy{$udn}->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '');
						my $result = $SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, SONOS_GetTagData('res', $queueMetadata->getValue('Result')), '');
						$answer .= ', Startlist: '.SONOS_UPnPAnswerMessage($result);
						
						# Play afterwards?
						if ($play) {
							$answer .= ', Play: '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Play(0, 1));
						}
						
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.substr($answer, 2)); # Das führende Komma wieder entfernen
					}
				} elsif ($workType eq 'deleteProxyObjects') {
					# Wird vom Sonos-Device selber in IsAlive benötigt
					SONOS_DeleteProxyObjects($udn);
					
					SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage(1));
				} elsif ($workType eq 'renewSubscription') {
					if (defined($SONOS_TransportSubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_TransportSubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_TransportSubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'Transport-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! Transport-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
					
					if (defined($SONOS_RenderingSubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_RenderingSubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_RenderingSubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'Rendering-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! Rendering-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
					
					if (defined($SONOS_AlarmSubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_AlarmSubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_AlarmSubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'Alarm-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! Alarm-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
					
					if (defined($SONOS_ZoneGroupTopologySubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_ZoneGroupTopologySubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_ZoneGroupTopologySubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'ZoneGroupTopology-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! ZoneGroupTopology-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
					
					if (defined($SONOS_DevicePropertiesSubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_DevicePropertiesSubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_DevicePropertiesSubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'DeviceProperties-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! DeviceProperties-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
					
					if (defined($SONOS_AudioInSubscriptions{$udn}) && (Time::HiRes::time() - $SONOS_AudioInSubscriptions{$udn}->{_startTime} > $SONOS_SUBSCRIPTIONSRENEWAL)) {
						eval {
							$SONOS_AudioInSubscriptions{$udn}->renew();
							SONOS_Log $udn, 3, 'AudioIn-Subscription for ZonePlayer "'.$udn.'" has expired and is now renewed.';
						};
						if ($@) {
							SONOS_Log $udn, 3, 'Error! AudioIn-Subscription for ZonePlayer "'.$udn.'" has expired and could not be renewed: '.$@;
							
							# Wenn der Player nicht erreichbar war, dann entsprechend entfernen...
							# Hier aber nur eine kleine Lösung, da es nur ein Notbehelf sein soll...
							if ($@ =~ m/Can.t connect to/) {
								SONOS_DeleteProxyObjects($udn);
							}
						}
					}
				} elsif ($workType eq 'playURI') {
					my $songURI = SONOS_ExpandURIForQueueing($params[0]);
					
					my $volume;
					if ($#params > 0) {
						$volume = $params[1];
					}
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						my ($uri, $meta) = SONOS_CreateURIMeta($songURI);
						$SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, $uri, $meta);
						
						if (defined($volume)) {
							if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
								$SONOS_GroupRenderingControlProxy{$udn}->SnapshotGroupVolume(0);
								if ($volume =~ m/^[+-]{1}/) {
									$SONOS_GroupRenderingControlProxy{$udn}->SetRelativeGroupVolume(0, $volume)
								} else {
									$SONOS_GroupRenderingControlProxy{$udn}->SetGroupVolume(0, $volume);
								}
							}
						}
					
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_AnswerMessage($SONOS_AVTransportControlProxy{$udn}->Play(0, 1)->isSuccessful));
					}
				} elsif ($workType eq 'playURITemp') {
					my $destURL = $params[0];
					
					my $volume;
					if ($#params > 0) {
						$volume = $params[1];
					}
					
					SONOS_PlayURITemp($udn, $destURL, $volume);
				} elsif ($workType eq 'addURIToQueue') {
					my $songURI = SONOS_ExpandURIForQueueing($params[0]);
					
					if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
						my $track = $SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('Track');
						
						my ($uri, $meta) = SONOS_CreateURIMeta($songURI);
						SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->AddURIToQueue(0, $uri, $meta, $track + 1, 1)));
					}
				} elsif ($workType =~ m/speak\d+/i) {
					my $volume = $params[0];
					my $language = $params[1];
					
					my $text = $params[2];
					for(my $i = 3; $i < @params; $i++) {
						$text .= ','.$params[$i];
					}
					$text =~ s/^ *(.*) *$/$1/g;
					$text = SONOS_Utf8ToLatin1($text);
					
					my $digest = '';
					if (SONOS_Client_Data_Retreive('undef', 'attr', 'targetSpeakFileHashCache', 0) == 1) {
						eval {
							require Digest::SHA1;
							import Digest::SHA1 qw(sha1_hex);
							$digest = '_'.sha1_hex(lc($text));
						};
						if ($@ =~ /Can't locate Digest\/SHA1.pm in/i) {
							# Unter Ubuntu gibt es die SHA1-Library nicht mehr, sodass man dort eine andere einbinden muss (SHA)
							eval {
								require Digest::SHA;
								import Digest::SHA qw(sha1_hex);
								$digest = '_'.sha1_hex(lc($text));
							};
						}
						if ($@) {
							SONOS_Log $udn, 2, 'Beim Ermitteln des Hash-Wertes ist ein Fehler aufgetreten: '.$@;
							return;
						}
					}
					
					my $timestamp = '';
					if (!$digest && SONOS_Client_Data_Retreive('undef', 'attr', 'targetSpeakFileTimestamp', 0) == 1) {
						my @timearray = localtime;
						$timestamp = sprintf("_%04d%02d%02d-%02d%02d%02d", $timearray[5]+1900,$timearray[4]+1,$timearray[3], $timearray[2],$timearray[1],$timearray[0]);
					}
					
					my $fileExtension = SONOS_GetSpeakFileExtension($workType);
					my $dest = SONOS_Client_Data_Retreive('undef', 'attr', 'targetSpeakDir', '.').'/'.$udn.'_Speak'.$timestamp.$digest.'.'.$fileExtension;
					my $destURL = SONOS_Client_Data_Retreive('undef', 'attr', 'targetSpeakURL', '').'/'.$udn.'_Speak'.$timestamp.$digest.'.'.$fileExtension;
					
					if ($digest && (-e $dest)) {
						SONOS_Log $udn, 3, 'Hole die Durchsage aus dem Cache...';
					} else {
						if (!SONOS_GetSpeakFile($udn, $workType, $language, $text, $dest)) {
							return;
						}
						
						# MP3-Tags setzen, wenn die entsprechende Library gefunden wurde, und die Ausgabe in ein MP3-Format erfolgte
						if (lc(substr($dest, -3, 3)) eq 'mp3') {
							eval {
								my $mp3GroundPath = SONOS_GetAbsolutePath($0);
								$mp3GroundPath = substr($mp3GroundPath, 0, rindex($mp3GroundPath, '/'));
								
								require MP3::Tag;
								my $mp3 = MP3::Tag->new($dest);
								
								$mp3->title_set($text);
								$mp3->artist_set('FHEM ~ Sonos');
								$mp3->album_set('Sprachdurchsagen');
								my $coverPath = SONOS_Client_Data_Retreive('undef', 'attr', ucfirst(lc(($workType =~ /0$/) ? 'speak' : $workType)).'Cover', $mp3GroundPath.'/www/images/default/fhemicon.png');
								my $imgfile = SONOS_ReadFile($coverPath);
								$mp3->set_id3v2_frame('APIC', 0, (($coverPath =~ m/\.png$/) ? 'image/png' : 'image/jpeg'), chr(3), 'Cover Image', $imgfile) if ($imgfile);
								$mp3->update_tags();
							};
							if ($@) {
								SONOS_Log $udn, 2, 'Beim Setzen der MP3-Informationen (ID3TagV2) ist ein Fehler aufgetreten: '.$@;
							}
						}
					}
					
					SONOS_PlayURITemp($udn, $destURL, $volume);
				} else {
					SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': DoWork-Syntax ERROR');
				}
			};
			if ($@) {
				SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', 'DoWork-Exception ERROR: '.$@);
			}
			
			$SONOS_ComObjectTransportQueue->dequeue();
		}
		
		return 1;
	};

	my $error;
	do {
		eval {
			$SONOS_Controlpoint = UPnP::ControlPoint->new(SearchPort => 8008 + threads->tid() - 1, SubscriptionPort => 9009 + threads->tid() - 1, SubscriptionURL => '/eventSub', MaxWait => 30, IgnoreIP => \%IgnoreIPs);
			$SONOS_Search = $SONOS_Controlpoint->searchByType('urn:schemas-upnp-org:device:ZonePlayer:1', \&SONOS_Discover_Callback);
			$SONOS_Controlpoint->handle;
		};
		$error = $@;
		
		# Nur wenn es der Fehler mit der XML-Struktur ist, dann den UPnP-Handler nochmal anstarten...  
		if (($error =~ m/multiple roots, wrong element '.*?'/si) || ($error =~ m/junk '.*?' after XML element/si) || ($error =~ m/mismatched tag '.*?'/si) || ($error =~ m/500 Can't connect to/si)) {
			SONOS_Log undef, 2, "Error during UPnP-Handling, restarting handling: $error";
			SONOS_StopControlPoint();
		} else {
			SONOS_Log undef, 2, "Error during UPnP-Handling: $error";
			SONOS_StopControlPoint();
			
			# <spi> => Vielleicht noch auskommentieren
			undef($error);
		}
	} while ($error);
	
	SONOS_Log undef, 3, 'UPnP-Thread wurde beendet.';
	$SONOS_Thread = -1;
	
	return 1;
}

########################################################################################
#
#  SONOS_MakeCoverURL - Generates the approbriate cover-url incl. the use of an Fhem-Proxy
#
########################################################################################
sub SONOS_MakeCoverURL($$) {
	my ($udn, $resURL) = @_;
	
	if ($resURL =~ m/^(x-rincon-cpcontainer|x-sonos-spotify).*?(spotify.*?)(\?|$)/i) {
		my $infos = get('https://embed.spotify.com/oembed/?url='.$2);
		
		if ($infos =~ m/"thumbnail_url":"(.*?)cover(.*?)"/i) {
			$resURL = $1.'original'.$2;
			$resURL =~ s/\\//g;
		}
	} elsif($resURL =~ m/savedqueues/i) {
		$resURL = '/fhem/sonos/cover/playlist.jpg';
	} else {
		my $stream = 0;
		$stream = 1 if ($resURL =~ /x-sonosapi-stream/);
		$resURL = $1.'/getaa?'.($stream ? 's=1&' : '').'u='.uri_escape($resURL) if (SONOS_Client_Data_Retreive($udn, 'reading', 'location', '') =~ m/^(http:\/\/.*?:.*?)\//i);
	}
	
	# Alles über Fhem als Proxy laufen lassen?
	$resURL = '/fhem/sonos/proxy/aa?url='.uri_escape($resURL) if (($resURL !~ m/^\//) && SONOS_Client_Data_Retreive('undef', 'attr', 'generateProxyAlbumArtURLs', 0));
	
	return $resURL;
}

########################################################################################
#
#  SONOS_GetSpeakFileExtension - Retrieves the desired fileextension
#
########################################################################################
sub SONOS_GetSpeakFileExtension($) {
	my ($workType) = @_;
	
	if (lc($workType) eq 'speak0') {
		return 'mp3';
	} elsif ($workType =~ m/speak\d+/i) {
		$workType = ucfirst(lc($workType));
		
		my $speakDefinition = SONOS_Client_Data_Retreive('undef', 'attr', $workType, 0);
		if ($speakDefinition =~ m/(.*?):(.*)/) {
			return $1;
		}
	}
	
	return '';
}

########################################################################################
#
#  SONOS_GetSpeakFile - Generates the audiofile according to the given text, language and generator
#
########################################################################################
sub SONOS_GetSpeakFile($$$$$) {
	my ($udn, $workType, $language, $text, $destFileName) = @_;
	
	if (lc($workType) eq 'speak0') {
		# Chunks ermitteln...
		# my @textList = ($text =~ m/(?:\b(?:[^ ]+)\W*){0,$SONOS_GOOGLETRANSLATOR_CHUNKSIZE}/g);
		# pop @textList; # Letztes Element ist immer leer, deshalb abschneiden...
		my @textList = ('');
		for my $elem (split(/[ \t]/, $text)) {
			if (length($textList[$#textList].' '.$elem) <= $SONOS_GOOGLETRANSLATOR_CHUNKSIZE) {
				$textList[$#textList] .= ' '.$elem;
			} else {
				push(@textList, $elem);
			}
		}
		SONOS_Log $udn, 5, 'Chunks: '.SONOS_Stringify(\@textList);
		
		# Einzelne Chunks herunterladen...
		my $counter = 0;
		for my $text (@textList) {
			$counter++;
			
			my $url = 'http://translate.google.com/translate_tts?tl='.uri_escape(lc($language)).'&q='.uri_escape($text);
		
			SONOS_Log $udn, 3, 'Load Google generated MP3 ('.$counter.'. Element) from "'.$url.'" to "'.$destFileName.$counter.'"';
			
			my $ua = LWP::UserAgent->new(agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.64 Safari/537.11');
			my $response = $ua->get($url, ':content_file' => $destFileName.$counter);
			if (!$response->is_success) {
				SONOS_Log $udn, 1, 'MP3 Download-Error: '.$response->status_line;
				unlink($destFileName.$counter);
				
				SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': MP3-Creation ERROR during downloading.');
				return 0;
			}
		}
		
		# Heruntergeladene Chunks zusammenführen...
		SONOS_Log $udn, 3, 'Combine loaded chunks into "'.$destFileName.'"';
		
		# Reinladen
		my $newMP3File = '';
		for(my $i = 1; $i <= $counter; $i++) {
			$newMP3File .= SONOS_ReadFile($destFileName.$i);
			unlink($destFileName.$i)
		}
		# Speichern
		if (defined(open MPFILE, '>'.$destFileName)) {
			binmode MPFILE ;
			print MPFILE $newMP3File;
			close MPFILE;
		} else {
			SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': MP3-Creation ERROR during combining.');
			return 0;
		}
		
		return 1;
	} elsif ($workType =~ m/speak\d+/i) {
		$workType = ucfirst(lc($workType));
		SONOS_Log $udn, 3, 'Load '.$workType.' generated SpeakFile to "'.$destFileName.'"';
		
		my $speakDefinition = SONOS_Client_Data_Retreive('undef', 'attr', $workType, 0);
		if ($speakDefinition =~ m/(.*?):(.*)/) {
			$speakDefinition = $2;
			
			$speakDefinition =~ s/%language%/$language/gi;
			$speakDefinition =~ s/%filename%/$destFileName/gi;
			$speakDefinition =~ s/%text%/$text/gi;
			
			SONOS_Log $udn, 5, 'Execute: '.$speakDefinition;
			system($speakDefinition);
			
			return 1;
		} else {
			SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': No Definition found!');
			return 0;
		}
	}
	
	SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', ucfirst($workType).': Speaking not defined.');
	return 0;
}

########################################################################################
#
#  SONOS_CreateURIMeta - Creates the Meta-Information according to the Song-URI
#
#  Parameter $res = The URI to the song, for which the Metadata has to be generated
#
########################################################################################
sub SONOS_CreateURIMeta($) {
	my ($res) = @_;
	my $meta = $SONOS_DIDLHeader.'<item id="" parentID="" restricted="true"><dc:title></dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">RINCON_AssociatedZPUDN</desc></item>'.$SONOS_DIDLFooter;
	
	my $userID_Spotify = uri_unescape(SONOS_Client_Data_Retreive('undef', 'reading', 'UserID_Spotify', '-'));
	my $userID_Napster = uri_unescape(SONOS_Client_Data_Retreive('undef', 'reading', 'UserID_Napster', '-'));
	
	# Wenn es ein Spotify- oder Napster-Titel ist, dann den Benutzernamen extrahieren
	if ($res =~ m/^(x-sonos-spotify:)(.*?)(\?.*?)/) {
		if ($userID_Spotify eq '-') {
			SONOS_Log undef, 1, 'There are Spotify-Titles in list, and no Spotify-Username is known. Please empty the main queue and insert a random spotify-title in it for saving this information and do this action again!';
			return;
		}
	
		$res = $1.uri_escape($2).$3;
		$meta = $SONOS_DIDLHeader.'<item id="'.uri_escape($2).'" parentID="" restricted="true"><dc:title></dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">'.$userID_Spotify.'</desc></item>'.$SONOS_DIDLFooter;
	} elsif ($res =~ m/^(npsdy:)(.*?)(\.mp3)/) {
		if ($userID_Napster eq '-') {
			SONOS_Log undef, 1, 'There are Napster/Rhapsody-Titles in list, and no Napster-Username is known. Please empty the main queue and insert a random napster-title in it for saving this information and do this action again!';
			return;
		} 
	
		$res = $1.uri_escape($2).$3;
		$meta = $SONOS_DIDLHeader.'<item id="RDCPI:GLBTRACK:'.uri_escape($2).'" parentID="" restricted="true"><dc:title></dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">'.$userID_Napster.'</desc></item>'.$SONOS_DIDLFooter;
	} else {
		$res =~ s/ /%20/ig;
		$res =~ s/"/&quot;/ig;
	}
	
	return ($res, $meta);
}

########################################################################################
#
#  SONOS_CheckAlarmHash - Checks if the given hash has all neccessary Alarm-Parameters
#					Additionally it converts some parameters for direct use for Zoneplayer-Update
#
#  Parameter %old = All neccessary informations to check
#
########################################################################################
sub SONOS_CheckAndCorrectAlarmHash($) {
	my ($hash) = @_;
	
	# Checks, if a value is missing
	my @keys = keys(%$hash);
	if ((!SONOS_isInList('StartTime', @keys))
		|| (!SONOS_isInList('Duration', @keys))
		|| (!SONOS_isInList('Recurrence_Once', @keys))
		|| (!SONOS_isInList('Recurrence_Monday', @keys))
		|| (!SONOS_isInList('Recurrence_Tuesday', @keys))
		|| (!SONOS_isInList('Recurrence_Wednesday', @keys))
		|| (!SONOS_isInList('Recurrence_Thursday', @keys))
		|| (!SONOS_isInList('Recurrence_Friday', @keys))
		|| (!SONOS_isInList('Recurrence_Saturday', @keys))
		|| (!SONOS_isInList('Recurrence_Sunday', @keys))
		|| (!SONOS_isInList('Enabled', @keys))
		|| (!SONOS_isInList('RoomUUID', @keys))
		|| (!SONOS_isInList('ProgramURI', @keys))
		|| (!SONOS_isInList('ProgramMetaData', @keys))
		|| (!SONOS_isInList('Shuffle', @keys))
		|| (!SONOS_isInList('Repeat', @keys))
		|| (!SONOS_isInList('Volume', @keys))
		|| (!SONOS_isInList('IncludeLinkedZones', @keys))) {
		return 0;
	}
		
	# Converts some values
	# Playmode
	$hash->{PlayMode} = 'NORMAL';
	$hash->{PlayMode} = 'SHUFFLE' if ($hash->{Repeat} && $hash->{Shuffle});
	$hash->{PlayMode} = 'SHUFFLE_NOREPEAT' if (!$hash->{Repeat} && $hash->{Shuffle});
	$hash->{PlayMode} = 'REPEAT_ALL' if ($hash->{Repeat} && !$hash->{Shuffle});
	
	# Recurrence
	if ($hash->{Recurrence_Once}) {
		$hash->{Recurrence} = 'ONCE';
	} else {
		$hash->{Recurrence} = 'ON_';
		$hash->{Recurrence} .= '1' if ($hash->{Recurrence_Monday});
		$hash->{Recurrence} .= '2' if ($hash->{Recurrence_Tuesday});
		$hash->{Recurrence} .= '3' if ($hash->{Recurrence_Wednesday});
		$hash->{Recurrence} .= '4' if ($hash->{Recurrence_Thursday});
		$hash->{Recurrence} .= '5' if ($hash->{Recurrence_Friday});
		$hash->{Recurrence} .= '6' if ($hash->{Recurrence_Saturday});
		$hash->{Recurrence} .= '7' if ($hash->{Recurrence_Sunday});
	}
	
	# If nothing is given, set 'ONCE'
	if ($hash->{Recurrence} eq 'ON_') {
		$hash->{Recurrence} = 'ONCE';
	}
	
	return 1;
}

########################################################################################
#
#  SONOS_RestoreOldPlaystate - Restores the old Position of a playing state
#
########################################################################################
sub SONOS_RestoreOldPlaystate() {
	SONOS_Log undef, 1, 'Restore-Thread gestartet. Warte auf Arbeit...';
	
	my $runEndlessLoop = 1;
	my $controlPoint = UPnP::ControlPoint->new(SearchPort => 8008 + threads->tid() - 1, SubscriptionPort => 9009 + threads->tid() - 1, SubscriptionURL => '/eventSub', MaxWait => 20, IgnoreIP => \%IgnoreIPs);
	
	$SIG{'PIPE'} = 'IGNORE';
	$SIG{'CHLD'} = 'IGNORE';
	
	$SIG{'INT'} = sub {
		$runEndlessLoop = 0;
	};
	
	while ($runEndlessLoop) {
		select(undef, undef, undef, 0.2);
		next if (!$SONOS_PlayerRestoreQueue->pending());
		
		# Es ist was auf der Queue... versuchen zu verarbeiten...
		my %old = %{$SONOS_PlayerRestoreQueue->peek()};
		
		# Wenn die Zeit noch nicht reif ist, dann doch wieder übergehen...
		# Dabei die Schleife wieder von vorne beginnen lassen, da noch andere dazwischengeschoben werden könnten.
		# Eine Weile in die Zukunft, da das ermitteln der Proxies Zeit benötigt.
		next if ($old{RestoreTime} > time() + 1);
		
		# ...sonst das Ding von der Queue nehmen...
		$SONOS_PlayerRestoreQueue->dequeue();
		
		# Hier die ursprünglichen Proxies wiederherstellen/neu verbinden...
		my $device = $controlPoint->_createDevice($old{location});
		my $AVProxy;
		my $GRProxy;
		my $CCProxy;
		for my $subdevice ($device->children) {
			if ($subdevice->UDN =~ /.*_MR/i) {
				$AVProxy = $subdevice->getService('urn:schemas-upnp-org:service:AVTransport:1')->controlProxy();
				$GRProxy = $subdevice->getService('urn:schemas-upnp-org:service:GroupRenderingControl:1')->controlProxy();
			}
			
			if ($subdevice->UDN =~ /.*_MS/i) { 
				$CCProxy = $subdevice->getService('urn:schemas-upnp-org:service:ContentDirectory:1')->controlProxy();
			}
		}
		my $udn = $device->UDN.'_MR';
		$udn =~ s/.*?:(.*)/$1/;
	
		SONOS_Log $udn.'_MR', 3, 'Restorethread has found a job. Waiting for stop playing...';
		
		# Ist das Ding fertig abgespielt?
		my $result;
		do {
			select(undef, undef, undef, 0.5);
			$result = $AVProxy->GetTransportInfo(0);
		} while ($result->getValue('CurrentTransportState') ne 'STOPPED');
		
		
		SONOS_Log $udn, 3, 'Restoring playerstate...';
		# Die Liste als aktuelles Abspielstück einstellen, oder den Stream wieder anwerfen
		if ($old{CurrentURI} =~ /^x-.*?-.*?stream/) {
			$AVProxy->SetAVTransportURI(0, $old{CurrentURI}, $old{CurrentURIMetaData});
		} else {
			my $queueMetadata = $CCProxy->Browse('Q:0', 'BrowseMetadata', '', 0, 0, '');
			$AVProxy->SetAVTransportURI(0, SONOS_GetTagData('res', $queueMetadata->getValue('Result')), '');
			
			$AVProxy->Seek(0, 'TRACK_NR', $old{Track});
			$AVProxy->Seek(0, 'REL_TIME', $old{RelTime});
		}
		
		my $oldMute = $GRProxy->GetGroupMute(0)->getValue('CurrentMute');
		$GRProxy->SetGroupMute(0, $old{Mute}) if (defined($old{Mute}) && ($old{Mute} != $oldMute));
		
		my $oldVolume = $GRProxy->GetGroupVolume(0)->getValue('CurrentVolume');
		$GRProxy->SetGroupVolume(0, $old{Volume}) if (defined($old{Volume}) && ($old{Volume} != $oldVolume));
		
		if (($old{CurrentTransportState} eq 'PLAYING') || ($old{CurrentTransportState} eq 'TRANSITIONING')) {
			$AVProxy->Play(0, 1);
		} elsif ($old{CurrentTransportState} eq 'PAUSED_PLAYBACK') {
			$AVProxy->Pause(0); 
		}
		
		$SONOS_PlayerRestoreRunningUDN{$udn} = 0;
		SONOS_Log $udn, 3, 'Playerstate restored!';
	}
	
	undef($controlPoint);
	
	SONOS_Log undef, 1, 'Restore-Thread wurde beendet.';
	$SONOS_Thread_PlayerRestore = -1;
}

########################################################################################
#
#  SONOS_PlayURITemp - Plays an URI temporary
#
#  Parameter $udn = The udn of the SonosPlayer
#			$destURLParam = URI, that has to be played
#			$volumeParam = Volume for playing
#
########################################################################################
sub SONOS_PlayURITemp($$$) {
	my ($udn, $destURLParam, $volumeParam) = @_;
	
	my %old;
	$old{DestURIOriginal} = $destURLParam;
	my ($songURI, $meta) = SONOS_CreateURIMeta(SONOS_ExpandURIForQueueing($old{DestURIOriginal}));
	
	# Wenn auf diesem Player bereits eine temporäre Wiedergabe erfolgt, dann hier auf dessen Beendigung warten...
	if (defined($SONOS_PlayerRestoreRunningUDN{$udn}) && $SONOS_PlayerRestoreRunningUDN{$udn}) {
		SONOS_Log $udn, 3, 'Temporary playing of "'.$old{DestURIOriginal}.'" must wait, because another playing is in work...';
		
		while (defined($SONOS_PlayerRestoreRunningUDN{$udn}) && $SONOS_PlayerRestoreRunningUDN{$udn}) {
			select(undef, undef, undef, 0.2);
		}
	}
	
	$SONOS_PlayerRestoreRunningUDN{$udn} = 1;
	
	SONOS_Log $udn, 3, 'Start temporary playing of "'.$old{DestURIOriginal}.'"';
	
	my $volume = $volumeParam;
	
	if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
		$old{UDN} = $udn;
		
		my $result = $SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0);
		$old{Track} = $result->getValue('Track');
		$old{RelTime} = $result->getValue('RelTime');
		
		$result = $SONOS_AVTransportControlProxy{$udn}->GetMediaInfo(0);
		$old{CurrentURI} = $result->getValue('CurrentURI');
		$old{CurrentURIMetaData} = $result->getValue('CurrentURIMetaData');
		
		$result = $SONOS_AVTransportControlProxy{$udn}->GetTransportInfo(0);
		$old{CurrentTransportState} = $result->getValue('CurrentTransportState');
		
		$SONOS_AVTransportControlProxy{$udn}->SetAVTransportURI(0, $songURI, $meta);
		
		if (SONOS_CheckProxyObject($udn, $SONOS_GroupRenderingControlProxy{$udn})) {
			$SONOS_GroupRenderingControlProxy{$udn}->SnapshotGroupVolume(0);
			
			$old{Mute} = $SONOS_GroupRenderingControlProxy{$udn}->GetGroupMute(0)->getValue('CurrentMute');
			$SONOS_GroupRenderingControlProxy{$udn}->SetGroupMute(0, 0) if $old{Mute};
		
			$old{Volume} = $SONOS_GroupRenderingControlProxy{$udn}->GetGroupVolume(0)->getValue('CurrentVolume');
			if (defined($volume)) {
				if ($volume =~ m/^[+-]{1}/) {
					$SONOS_GroupRenderingControlProxy{$udn}->SetRelativeGroupVolume(0, $volume) if $volume;
				} else {
					$SONOS_GroupRenderingControlProxy{$udn}->SetGroupVolume(0, $volume) if ($volume != $old{Volume});
				}
			}
		}
	
		SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', 'PlayURITemp: '.SONOS_UPnPAnswerMessage($SONOS_AVTransportControlProxy{$udn}->Play(0, 1)));
		
		SONOS_Log $udn, 4, 'All is started successfully. Retreive Positioninfo...';
		$old{SleepTime} = 0;
		eval {
			$old{SleepTime} = SONOS_GetTimeSeconds($SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('TrackDuration'));
			
			# Wenn es keine Laufzeitangabe gibt, dann muss diese selber berechnet werden, sofern möglich. Sollte dies nicht möglich sein, ist dies vermutlich ein Stream...
			if ($old{SleepTime} == 0) {
				SONOS_Log $udn, 3, 'SleepTimer berechnet die Laufzeit des Titels selber, da keine Wartezeit uebermittelt wurde!';
				
				eval {
					use MP3::Info;
					my $tag = get_mp3info($old{DestURIOriginal});
					if ($tag) {
						$old{SleepTime} = $tag->{SECS};
					}
				};
				if ($@) {
					SONOS_Log $udn, 2, 'Bei der MP3-Längenermittlung ist ein Fehler aufgetreten: '.$@;
				}
			}
			
			$old{RestoreTime} = time() + $old{SleepTime} - 1;
			SONOS_Log $udn, 3, 'Laufzeitermittlung abgeschlossen: '.$old{SleepTime}.'s, Restore-Zeit: '.GetTimeString($old{RestoreTime});
		};
		
		# Location mitsichern, damit die Proxies neu geholt werden können
		my %revUDNs = reverse %SONOS_Locations;
		$old{location} = $revUDNs{$udn};

		# Restore-Daten an der richtigen Stelle auf die Queue legen, damit der Player-Restore-Thread sich darum kümmern kann
		# Aber nur, wenn auch ein Restore erfolgen kann, weil eine Zeit existiert
		if (defined($old{SleepTime}) && ($old{SleepTime} != 0)) {
			my $i;
			for ($i = $SONOS_PlayerRestoreQueue->pending() - 1; $i >= 0; $i--) {
				my %tmpOld = %{$SONOS_PlayerRestoreQueue->peek($i)};
				last if ($old{RestoreTime} > $tmpOld{RestoreTime});
			}
			
			$SONOS_PlayerRestoreQueue->insert($i + 1, \%old);
		} else {
			SONOS_Log $udn, 1, 'Da keine Endzeit ermittelt werden konnte, wird kein Restoring durchgeführt werden!';
			$SONOS_PlayerRestoreRunningUDN{$udn} = 0;
		}
	}
}

########################################################################################
#
#  SONOS_ExpandURIForQueueing - Expands and corrects a given URI
#
#  Parameter $songURI = The URI that has to be converted
#
########################################################################################
sub SONOS_ExpandURIForQueueing($) {
	my ($songURI) = @_;
	
	# Backslashe umwandeln
	$songURI =~ s/\\/\//g;
	
	# SongURI erweitern/korrigieren
	$songURI = 'x-file-cifs:'.$songURI if ($songURI =~ m/^\/\//);
	$songURI = 'x-rincon-mp3radio:'.$1 if ($songURI =~ m/^http:(\/\/.*)/);
	
	return $songURI;
}

########################################################################################
#
#  SONOS_GetURIFromQueueValue - Gets the URI from current Informations
#
#  Parameter $songURI = The URI that has to be converted
#
########################################################################################
sub SONOS_GetURIFromQueueValue($) {
	my ($songURI) = @_;
	
	# SongURI erweitern/korrigieren
	$songURI = $1 if ($songURI =~ m/^x-file-cifs:(.*)/i);
	$songURI = 'http:'.$1 if ($songURI =~ m/^x-rincon-mp3radio:(.*)/i);
	$songURI = uri_unescape($songURI) if ($songURI =~ m/^x-sonos-spotify:/i);
	
	return $songURI;
}

########################################################################################
#
#  SONOS_GetTimeSeconds - Converts a Time-String like '0:04:12' to seconds (e.g. 252)
#
#  Parameter $timeStr = The timeStr that has to be converted
#
########################################################################################
sub SONOS_GetTimeSeconds($) {
	my ($timeStr) = @_;
	
	return SONOS_Max(int($1)*3600 + int($2)*60 + int($3), 1) if ($timeStr =~ m/(\d+):(\d+):(\d+)/);
	return 0;
}

########################################################################################
#
#  SONOS_CheckProxyObject - Checks for existence of $proxyObject (=return 1) or not (=return 0). Additionally in case of error it lays an error-answer in the queue
#
#  Parameter $proxyObject = The Proxy that has to be checked
#
########################################################################################
sub SONOS_CheckProxyObject($$) {
	my ($udn, $proxyObject) = @_;
	
	if (defined($proxyObject)) {
		SONOS_Log $udn, 4, 'ProxyObject exists: '.$proxyObject;
		
		return 1;
	} else {
		SONOS_Log $udn, 3, 'ProxyObject does not exists';
		
		# Das Aufräumen der ProxyObjects und das Erzeugen des Notify wurde absichtlich nicht hier reingeschrieben, da es besser im IsAlive-Checker aufgehoben ist.
		SONOS_MakeSigHandlerReturnValue($udn, 'LastActionResult', 'CheckProxyObject-ERROR: SonosPlayer disappeared?');
		return 0;
	}
}

########################################################################################
#
#  SONOS_MakeSigHandlerReturnValue - Enqueue all necessary elements on upward-queue
#
#  Parameter $returnValue = The value that has to be laid on the queue.
#
########################################################################################
sub SONOS_MakeSigHandlerReturnValue($$$) {
	my ($udn, $returnName, $returnValue) = @_;
	
	#Antwort melden
	SONOS_Client_Notifier('DoWorkAnswer:'.$udn.':'.$returnName.':'.$returnValue);
}

########################################################################################
#
#  SONOS_StopControlPoint - Stops all open Net-Handles and Search-Token of the UPnP Part
#
########################################################################################
sub SONOS_StopControlPoint {
	if (defined($SONOS_Controlpoint)) {
		$SONOS_Controlpoint->stopSearch($SONOS_Search); 
		$SONOS_Controlpoint->stopHandling();
		undef($SONOS_Controlpoint);
		
		SONOS_Log undef, 4, 'ControlPoint is successfully stopped!';
	} 
}

########################################################################################
#
#  SONOS_GetTagData - Return the content of the given tag in the given string
#
# Parameter $tagName = The tag to be searched for
#			$data = The string in which to search for
#
########################################################################################
sub SONOS_GetTagData($$) {
	my ($tagName, $data) = @_;
	
	return $1 if ($data =~ m/<$tagName.*?>(.*?)<\/$tagName>/i);
	return '';
}

########################################################################################
#
#  SONOS_AnswerMessage - Return 'Success' if param is true, 'Error' otherwise
#
# Parameter $var = The value to check
#
########################################################################################
sub SONOS_AnswerMessage($) {
	my ($var) = @_;
	
	if ($var) {
		return 'Success!';
	} else {
		return 'Error!';
	}
}

########################################################################################
#
#  SONOS_UPnPAnswerMessage - Return 'Success' if param is true, a complete error-message of the UPnP-answer otherwise
#
# Parameter $var = The UPnP-answer to check
#
########################################################################################
sub SONOS_UPnPAnswerMessage($) {
	my ($var) = @_;
	
	if ($var->isSuccessful) {
		return 'Success!';
	} else {
		my $faultcode = '-';
		my $faultstring = '-';
		my $faultactor = '-';
		my $faultdetail = '-';
		
		$faultcode = $var->faultcode if ($var->faultcode);
		$faultstring = $var->faultstring if ($var->faultstring);
		$faultactor = $var->faultactor if ($var->faultactor);
		$faultdetail = $var->faultdetail if ($var->faultdetail);
		
		return 'Error! UPnP-Fault-Fields: Code: "'.$faultcode.'", String: "'.$faultstring.'", Actor: "'.$faultactor.'", Detail: "'.SONOS_Stringify($faultdetail).'"';
	}
}

########################################################################################
#
#  SONOS_Stringify - Converts a given Value (Array, Hash, Scalar) to a readable string version
#
# Parameter $varRef = The value to convert to a readable version
#
########################################################################################
sub SONOS_Stringify {
	my ($varRef) = @_;
	
	return 'undef' if (!defined($varRef));
	
	my $reftype = reftype $varRef;
	if (!defined($reftype) || ($reftype eq '')) {
		if (looks_like_number($varRef)) {
			return $varRef;
		} else {
			$varRef =~ s/'/\\'/g;
			return "'".$varRef."'";
		}
	} elsif ($reftype eq 'HASH') {
		my %var = %{$varRef};
		
		my @result;
		foreach my $key (keys %var) {
			push(@result, $key.' => '.SONOS_Stringify($var{$key}));
		}
		
		return '{'.join(', ', @result).'}';
	} elsif ($reftype eq 'ARRAY') {
		my @var = @{$varRef};
	
		my @result;
		foreach my $value (@var) {
			push(@result, SONOS_Stringify($value));
		}
	
		return '['.join(', ', @result).']';
	} elsif ($reftype eq 'SCALAR') {
		if (looks_like_number(${$varRef})) {
			return ${$varRef};
		} else {
			${$varRef} =~ s/'/\\'/g;
			return "'".${$varRef}."'";
		}
	} else {
		return 'Unsupported Type ('.$reftype.') of: '.$varRef;
	}
}

########################################################################################
#
#  SONOS_UmlautConvert - Converts any umlaut (e.g. ä) to Ascii-conform writing (e.g. ae)
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_UmlautConvert($) {
	my ($var) = @_;
	
	if ($var eq 'ä') {
		return 'ae';
	} elsif ($var eq 'ö') {
		return 'oe';
	} elsif ($var eq 'ü') {
		return 'ue';
	} elsif ($var eq 'Ä') {
		return 'Ae';
	} elsif ($var eq 'Ö') {
		return 'Oe';
	} elsif ($var eq 'Ü') {
		return 'Ue';
	} elsif ($var eq 'ß') {
		return 'ss';
	} else {
		return '_';
	}
}

########################################################################################
#
#  SONOS_ConvertUmlautToHtml - Converts any umlaut (e.g. ä) to Html-conform writing (e.g. &auml;)
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_ConvertUmlautToHtml($) {
	my ($var) = @_;
	
	if ($var eq 'ä') {
		return '&auml;';
	} elsif ($var eq 'ö') {
		return '&ouml;';
	} elsif ($var eq 'ü') {
		return '&uuml;';
	} elsif ($var eq 'Ä') {
		return '&Auml;';
	} elsif ($var eq 'Ö') {
		return '&Ouml;';
	} elsif ($var eq 'Ü') {
		return '&Uuml;';
	} elsif ($var eq 'ß') {
		return '&szlig;';
	} else {
		return $var;
	}
}

########################################################################################
#
#  SONOS_Latin1ToUtf8 - Converts Latin1 coding to UTF8
#
# Parameter $var = The value to convert
#
# http://perldoc.perl.org/perluniintro.html, UNICODE IN OLDER PERLS
#
########################################################################################
sub SONOS_Latin1ToUtf8($) {
  my ($s)= @_;
  
  $s =~ s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
  
  return $s;
}

########################################################################################
#
#  SONOS_Utf8ToLatin1 - Converts UTF8 coding to Latin1
#
# Parameter $var = The value to convert
#
# http://perldoc.perl.org/perluniintro.html, UNICODE IN OLDER PERLS
#
########################################################################################
sub SONOS_Utf8ToLatin1($) {
  my ($s)= @_;
  
  $s =~ s/([\xC2\xC3])([\x80-\xBF])/chr(ord($1)<<6&0xC0|ord($2)&0x3F)/eg;
  
  return $s;
}

########################################################################################
#
#  SONOS_ConvertNumToWord - Converts the values "0, 1" to "off, on"
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_ConvertNumToWord($) {
	my ($var) = @_;
	
	if (!looks_like_number($var)) {
		return 'on' if (lc($var) ne 'off');
		return 'off';
	}
	
	if ($var == 0) {
		return 'off';
	} else {
		return 'on';
	}
}

########################################################################################
#
#  SONOS_ConvertWordToNum - Converts the values "off, on" to "0, 1"
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_ConvertWordToNum($) {
	my ($var) = @_;
	
	if (looks_like_number($var)) {
		return 1 if ($var != 0);
		return 0;
	}
	
	if (lc($var) eq 'off') {
		return 0;
	} else {
		return 1;
	}
}

########################################################################################
#
#  SONOS_ToggleNum - Convert the values "0, 1" to "1, 0"
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_ToggleNum($) {
	my ($var) = @_;
	
	if ($var == 0) {
		return 1;
	} else {
		return 0;
	}
}

########################################################################################
#
#  SONOS_ToggleWord - Convert the values "off, on" to "on, off"
#
# Parameter $var = The value to convert
#
########################################################################################
sub SONOS_ToggleWord($) {
	my ($var) = @_;
	
	if (lc($var) eq 'off') {
		return 'on';
	} else {
		return 'off';
	}
}

########################################################################################
#
#  SONOS_Discover_Callback - Discover-Callback, 
#                   				 autocreate devices if not already present
#
# Parameter $search = 
#			$device = 
#			$action =
#
########################################################################################
sub SONOS_Discover_Callback($$$) {
	my ($search, $device, $action) = @_;
	
	# Sicherheitsabfrage, da offensichtlich manchmal falsche Elemente durchkommen...
	if ($device->deviceType() ne 'urn:schemas-upnp-org:device:ZonePlayer:1') {
		SONOS_Log undef, 2, 'Discover-Event: Wrong deviceType "'.$device->deviceType().'" received!';
		return;
	}
	
	if ($action eq 'deviceAdded') {
		my $descriptionDocument;
		eval {
			$descriptionDocument = decode(SONOS_Client_Data_Retreive('undef', 'attr', 'characterDecoding', 'CP-1252'), $device->descriptionDocument());
		};
		if ($@) {
			# Das Descriptiondocument konnte nicht abgefragt werden
			SONOS_Log undef, 2, 'Discover-Event: Wrong deviceType "'.$device->deviceType().'" received! Detected while trying to download the Description-Document from Player.';
			return;
		}
		
		# Wenn kein Description-Dokument geliefert wurde...
		if (!defined($descriptionDocument) || ($descriptionDocument eq '')) {
			SONOS_Log undef, 2, "Discover-Event: Description-Document is empty. Aborting this deviceadding-process.";
			return;
		}
		
		# Alles OK, es kann weitergehen
		SONOS_Log undef, 4, "Discover-Event: Description-Document: $descriptionDocument";
		
		$SONOS_Client_SendQueue_Suspend = 1;
	
		# Variablen initialisieren
		my $roomName = '';
		my $saveRoomName = '';
		my $modelNumber = '';
		my $displayVersion = '';
		my $serialNum = '';
		my $iconURI = '';
	
		# Um einen XML-Parser zu vermeiden, werden hier reguläre Ausdrücke für die Ermittlung der Werte eingesetzt...
		# RoomName ermitteln
		$roomName = decode_entities($1) if ($descriptionDocument =~ m/<roomName>(.*?)<\/roomName>/im);
		$saveRoomName = decode('UTF-8', $roomName);
		$saveRoomName =~ s/([äöüÄÖÜß])/SONOS_UmlautConvert($1)/eg; # Hier erstmal Umlaute 'schön' machen, damit dafür nicht '_' verwendet werden...
		$saveRoomName =~ s/[^a-zA-Z0-9]/_/g;
		my $groupName = $saveRoomName;
	
		# Modelnumber ermitteln
		$modelNumber = decode_entities($1) if ($descriptionDocument =~ m/<modelNumber>(.*?)<\/modelNumber>/im);
		
		# DisplayVersion ermitteln
		$displayVersion = decode_entities($1) if ($descriptionDocument =~ m/<displayVersion>(.*?)<\/displayVersion>/im);
	
		# SerialNum ermitteln
		$serialNum = decode_entities($1) if ($descriptionDocument =~ m/<serialNum>(.*?)<\/serialNum>/im);
	
		# Icon-URI ermitteln
		$iconURI = decode_entities($1) if ($descriptionDocument =~ m/<iconList>.*?<icon>.*?<id>0<\/id>.*?<url>(.*?)<\/url>.*?<\/icon>.*?<\/iconList>/sim);
	
		# Kompletten Pfad zum Download des ZonePlayer-Bildchens zusammenbauen
		my $iconOrigPath = $device->location();
		$iconOrigPath =~ s/(http:\/\/.*?)\/.*/$1$iconURI/i;
	
		# Zieldateiname für das ZonePlayer-Bildchen zusammenbauen
		my $iconPath = $iconURI;
		$iconPath =~ s/.*\/(.*)/icoSONOSPLAYER_$1/i;
		
		my $udnShort = $device->UDN;
		$udnShort =~ s/.*?://i;
		my $udn = $udnShort.'_MR';
		
		$SONOS_Locations{$device->location()} = $udn;
		
		my $name = $SONOS_Client_Data{SonosDeviceName}."_".$saveRoomName;
		
		# Erkannte Werte ausgeben...
		SONOS_Log undef, 4, "RoomName: '$roomName', SaveRoomName: '$saveRoomName', ModelNumber: '$modelNumber', DisplayVersion: '$displayVersion', SerialNum: '$serialNum', IconURI: '$iconURI', IconOrigPath: '$iconOrigPath', IconPath: '$iconPath'";
	
		SONOS_Log undef, 2, "Discover Sonosplayer '$roomName' ($modelNumber) Software Revision $displayVersion with ID '$udn'";
	
		# ServiceProxies für spätere Aufrufe merken
		my $alarmService = $device->getService('urn:schemas-upnp-org:service:AlarmClock:1');
		$SONOS_AlarmClockControlProxy{$udn} = $alarmService->controlProxy if ($alarmService);
		
		my $audioInService = $device->getService('urn:schemas-upnp-org:service:AudioIn:1');
		$SONOS_AudioInProxy{$udn} = $audioInService->controlProxy if ($audioInService);
		
		my $devicePropertiesService = $device->getService('urn:schemas-upnp-org:service:DeviceProperties:1');
		$SONOS_DevicePropertiesProxy{$udn} = $devicePropertiesService->controlProxy if ($devicePropertiesService);
		#$SONOS_GroupManagementProxy{$udn} = $device->getService('urn:schemas-upnp-org:service:GroupManagement:1')->controlProxy if ($device->getService('urn:schemas-upnp-org:service:GroupManagement:1'));
		#$SONOS_MusicServicesProxy{$udn} = $device->getService('urn:schemas-upnp-org:service:MusicServices:1')->controlProxy if ($device->getService('urn:schemas-upnp-org:service:MusicServices:1'));
		
		my $zoneGroupTopologyService = $device->getService('urn:schemas-upnp-org:service:ZoneGroupTopology:1');
		$SONOS_ZoneGroupTopologyProxy{$udn} = $zoneGroupTopologyService->controlProxy if ($zoneGroupTopologyService);
		
		# Bei einem Dock gibt es AVTransport nur am Hauptdevice, deshalb mal schauen, ob wir es hier bekommen können
		my $transportService = $device->getService('urn:schemas-upnp-org:service:AVTransport:1');
		$SONOS_AVTransportControlProxy{$udn} = $transportService->controlProxy if ($transportService);
		
		my $renderingService;

		# Hier die Subdevices durchgehen, da für die Anmeldung nur das "_MR"-Device (MediaRenderer) wichtig ist
		for my $subdevice ($device->children) {
			SONOS_Log undef, 4, 'SubDevice found: '.$subdevice->UDN;
			
			if ($subdevice->UDN =~ /.*_MR/i) {
				# Wir haben hier das Media-Renderer Subdevice
				$transportService = $subdevice->getService('urn:schemas-upnp-org:service:AVTransport:1');
	    		$SONOS_AVTransportControlProxy{$udn} = $transportService->controlProxy if ($transportService);
	    		
	    		$renderingService = $subdevice->getService('urn:schemas-upnp-org:service:RenderingControl:1');
	    		$SONOS_RenderingControlProxy{$udn} = $renderingService->controlProxy if ($renderingService);
	    		
	    		$SONOS_GroupRenderingControlProxy{$udn} = $subdevice->getService('urn:schemas-upnp-org:service:GroupRenderingControl:1')->controlProxy if ($subdevice->getService('urn:schemas-upnp-org:service:GroupRenderingControl:1'));
	    }
	    	
    	if ($subdevice->UDN =~ /.*_MS/i) { 
    		# Wir haben hier das Media-Server Subdevice
    		$SONOS_ContentDirectoryControlProxy{$udn} = $subdevice->getService('urn:schemas-upnp-org:service:ContentDirectory:1')->controlProxy if ($subdevice->getService('urn:schemas-upnp-org:service:ContentDirectory:1'));
    	}
	  }
		   
		SONOS_Log undef, 4, 'ControlProxies wurden gesichert';
		
		# ZoneTopology laden, um die Benennung der Fhem-Devices besser an die Realität anpassen zu können
		my $topoType = '';
		my $fieldType = '';
		my $master = 1;
		if ($SONOS_ZoneGroupTopologyProxy{$udn}) {
			my $zoneGroupState = $SONOS_ZoneGroupTopologyProxy{$udn}->GetZoneGroupState()->getValue('ZoneGroupState');
			SONOS_Log undef, 5, 'ZoneGroupState: '.$zoneGroupState;
			
			if ($zoneGroupState =~ m/.*(<ZoneGroup Coordinator="(RINCON_[0-9a-f]+)".*?>).*?(<(ZoneGroupMember|Satellite) UUID="$udnShort".*?(>|\/>))/is) {
				my $coordinator = $2;
				my $member = $3;
				
				# Ist dieser Player in einem ChannelMapSet (also einer Paarung) enthalten?
				if ($member =~ m/ChannelMapSet=".*?$udnShort:(.*?),(.*?)[;"]/is) {
					$topoType = '_'.$1;
				}
				
				# Ist dieser Player in einem HTSatChanMapSet (also einem Surround-System) enthalten?
				if ($member =~ m/HTSatChanMapSet=".*?$udnShort:(.*?)[;"]/is) {
					$topoType = '_'.$1;
					$topoType =~ s/,/_/g;
				}
				
				SONOS_Log undef, 4, 'Retrieved TopoType: '.$topoType;
				$fieldType = substr($topoType, 1) if ($topoType);
				
				my $invisible = 0;
				$invisible = 1 if ($member =~ m/Invisible="1"/i);
				
				my $isZoneBridge = 0;
				$isZoneBridge = 1 if ($member =~ m/IsZoneBridge="1"/i);
				
				$master = !$invisible || $isZoneBridge;
			}
			
			# Wenn der aktuelle Player der Master ist, dann kein Kürzel anhängen, 
			# damit gibt es immer einen Player, der den Raumnamen trägt, und die anderen enthalten Kürzel
			if ($master) {
				$topoType = '';
			}
		}
		$name .= $topoType;
		$saveRoomName .= $topoType;
		
		# Volume laden um diese im Reading ablegen zu können
		my $currentVolume = 0;
		my $balance = 0;
		if ($SONOS_RenderingControlProxy{$udn}) {
			eval {
				$currentVolume = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'Master')->getValue('CurrentVolume');
				
				# Balance ermitteln
				my $volumeLeft = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'LF')->getValue('CurrentVolume');
				my $volumeRight = $SONOS_RenderingControlProxy{$udn}->GetVolume(0, 'RF')->getValue('CurrentVolume');
				$balance = (-$volumeLeft) + $volumeRight;
				
				SONOS_Log undef, 4, 'Retrieve Current Volumelevels. Master: "'.$currentVolume.'", Balance: "'.$balance.'"';
			};
			if ($@) {
				$currentVolume = 0;
				$balance = 0;
				SONOS_Log undef, 4, 'Couldn\'t retrieve Current Volumelevels: '. $@;
			}
		} else {
			SONOS_Log undef, 4, 'Couldn\'t get any Volume Information due to missing RenderingControlProxy';
		}
		
		# Load official icon from zoneplayer and copy it to local place for FHEM-use
		SONOS_Client_Notifier('getstore(\''.$iconOrigPath.'\', $attr{global}{modpath}.\'/www/images/default/'.$iconPath."');\n");
		
		# Icons neu einlesen lassen
		SONOS_Client_Notifier('SONOS_RefreshIconsInFHEMWEB(\'/www/images/default/'.$iconPath.'\');');
		
		# Transport Informations to FHEM
		# Check if this device is already defined...
		if (!SONOS_isInList($udn, @{$SONOS_Client_Data{PlayerUDNs}})) {
			push @{$SONOS_Client_Data{PlayerUDNs}}, $udn;
			
			# Wenn der Name schon mal verwendet wurde, dann solange ein Kürzel anhängen, bis ein freier Name gefunden wurde...
			while (SONOS_isInList($name, @{$SONOS_Client_Data{PlayerNames}})) {
				$name .= '_X';
				$saveRoomName .= '_X';
				
				SONOS_Log undef, 2, "New Fhem-Name neccessary for '$roomName' -> '$name', ID '$udn'";
			}
			push @{$SONOS_Client_Data{PlayerNames}}, $name;
			
			my %elemValues = ();
			$SONOS_Client_Data{Buffer}->{$udn} = shared_clone(\%elemValues);
			
			# Define SonosPlayer-Device with attributes
			SONOS_Client_Notifier('CommandDefine:'.$name.' SONOSPLAYER '.$udn);
			SONOS_Client_Notifier('CommandAttr:'.$name.' room '.$SONOS_Client_Data{SonosDeviceName});
			SONOS_Client_Notifier('CommandAttr:'.$name.' group '.$groupName);
			SONOS_Client_Notifier('CommandAttr:'.$name.' icon '.$iconPath);
			SONOS_Client_Notifier('CommandAttr:'.$name.' sortby 1');
			SONOS_Client_Notifier('CommandAttr:'.$name.' userReadings Favourites:LastActionResult.*?GetFavouritesWithCovers.* { if (ReadingsVal("'.$name.'", "LastActionResult", "") =~ m/.*?: (.*)/) { return $1; } }, Radios:LastActionResult.*?GetRadiosWithCovers.* { if (ReadingsVal("'.$name.'", "LastActionResult", "") =~ m/.*?: (.*)/) { return $1; } }, Playlists:LastActionResult.*?GetPlaylistsWithCovers.* { if (ReadingsVal("'.$name.'", "LastActionResult", "") =~ m/.*?: (.*)/) { return $1; } }, currentTrackPosition:LastActionResult.*?GetCurrentTrackPosition.* { if (ReadingsVal("'.$name.'", "LastActionResult", "") =~ m/.*?: (.*)/) { return $1; } }');
			
			# Das folgende nicht für Bridges machen
			if ($modelNumber ne 'ZB100') {
				SONOS_Client_Notifier('CommandAttr:'.$name.' generateInfoSummarize1 <NormalAudio><Artist prefix="(" suffix=")"/><Title prefix=" \'" suffix="\'" ifempty="[Keine Musikdatei]"/><Album prefix=" vom Album \'" suffix="\'"/></NormalAudio> <StreamAudio><Sender suffix=":"/><SenderCurrent prefix=" \'" suffix="\' -"/><SenderInfo prefix=" "/></StreamAudio>');
				SONOS_Client_Notifier('CommandAttr:'.$name.' generateInfoSummarize2 <TransportState/><InfoSummarize1 prefix=" => "/>');
				SONOS_Client_Notifier('CommandAttr:'.$name.' generateInfoSummarize3 <Volume prefix="Lautstärke: "/><Mute instead=" ~ Kein Ton" ifempty=" ~ Ton An" emptyval="0"/> ~ Balance: <Balance ifempty="Mitte" emptyval="0"/><HeadphoneConnected instead=" ~ Kopfhörer aktiv" ifempty=" ~ Kein Kopfhörer" emptyval="0"/>');
				SONOS_Client_Notifier('CommandAttr:'.$name.' stateVariable Presence');
				SONOS_Client_Notifier('CommandAttr:'.$name.' getAlarms 1'); SONOS_Client_Data_Refresh('', $udn, 'getAlarms', 1);
				SONOS_Client_Notifier('CommandAttr:'.$name.' minVolume 0'); SONOS_Client_Data_Refresh('', $udn, 'minVolume', 0);
				
				#SONOS_Client_Notifier('CommandAttr:'.$name.' webCmd Play:Pause:Previous:Next:VolumeD:VolumeU:MuteT');
	
				# Define Weblink for AlbumArt with attributes
				#if ($master) {
				#	SONOS_Client_Notifier('CommandDefine:AlbumArt_'.$saveRoomName.' weblink image /fhem/icons/SONOSPLAYER/'.$name.'_AlbumArt'."\n");
				#	SONOS_Client_Notifier('CommandAttr:AlbumArt_'.$saveRoomName.' room '.$SONOS_Client_Data{SonosDeviceName});
				#	SONOS_Client_Notifier('CommandAttr:AlbumArt_'.$saveRoomName.' htmlattr width=\'200\'');
				#	SONOS_Client_Notifier('CommandAttr:AlbumArt_'.$saveRoomName.' group '.$groupName);
				#}
				
				# Define ReadingsGroup
				if ($master) {
					SONOS_Client_Notifier('CommandDefine:'.$name.'RG ReadingsGroup '.$name.':<{SONOS_getCoverTitleRG($DEVICE)}@infoSummarize2>');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RG room '.$SONOS_Client_Data{SonosDeviceName});
					SONOS_Client_Notifier('CommandAttr:'.$name.'RG group '.$groupName);
					SONOS_Client_Notifier('CommandAttr:'.$name.'RG sortby 2');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RG noheading 1');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RG nonames 1');
				}
				
				# Define Readingsgroup Listen
				if ($master) {
					SONOS_Client_Notifier('CommandDefine:'.$name.'RG_Favourites ReadingsGroup '.$name.':<{SONOS_getListRG($DEVICE,"Favourites",1)}@Favourites>');
					SONOS_Client_Notifier('CommandDefine:'.$name.'RG_Radios ReadingsGroup '.$name.':<{SONOS_getListRG($DEVICE,"Radios",1)}@Radios>');
					SONOS_Client_Notifier('CommandDefine:'.$name.'RG_Playlists ReadingsGroup '.$name.':<{SONOS_getListRG($DEVICE,"Playlists")}@Playlists>');
				}
				
				# Define RemoteControl
				if ($master) {
					SONOS_Client_Notifier('CommandDefine:'.$name.'RC remotecontrol');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC room hidden');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC group '.$SONOS_Client_Data{SonosDeviceName});
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC rc_iconpath icons/remotecontrol');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC rc_iconprefix black_btn_');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC row00 Play:PLAY,Pause:PAUSE,Previous:REWIND,Next:FF,VolumeD:VOLDOWN,VolumeU:VOLUP,MuteT:MUTE');
					
					SONOS_Client_Notifier('CommandDefine:'.$name.'RC_Notify notify '.$name.'RC set '.$name.' $EVENT');
					
					SONOS_Client_Notifier('CommandDefine:'.$name.'RC_Weblink weblink htmlCode {fhem("get '.$name.'RC htmlcode", 1)}');
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC_Weblink room '.$SONOS_Client_Data{SonosDeviceName});
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC_Weblink group '.$groupName);
					SONOS_Client_Notifier('CommandAttr:'.$name.'RC_Weblink sortby 3');
				}
			}
			
			SONOS_Log undef, 1, "Successfully autocreated SonosPlayer '$saveRoomName' ($modelNumber) Software Revision $displayVersion with ID '$udn'";
		} else {
			SONOS_Log undef, 2, "SonosPlayer '$saveRoomName' ($modelNumber) with ID '$udn' is already defined and will only be updated";
		}
	
		# Wenn der Player noch nicht auf der "Aktiv"-Liste steht, dann draufpacken...
		push @{$SONOS_Client_Data{PlayerAlive}}, $udn if (!SONOS_isInList($udn, @{$SONOS_Client_Data{PlayerAlive}}));
		SONOS_Client_Data_Refresh('', $udn, 'NAME', $name);
		
		# Readings aktualisieren
		SONOS_Client_Notifier('ReadingsBeginUpdate:'.$udn);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'presence', 'appeared');
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'Volume', $currentVolume);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'Balance', $balance);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'roomName', $roomName);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'saveRoomName', $saveRoomName);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'playerType', $modelNumber);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'Volume', $currentVolume);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'location', $device->location);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'softwareRevision', $displayVersion);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'serialNum', $serialNum);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'fieldType', $fieldType);
		SONOS_Client_Data_Refresh('', $udn, 'LastSubscriptionsRenew', SONOS_TimeNow());
		SONOS_Client_Notifier('ReadingsEndUpdate:'.$udn);
		
		SONOS_Client_Notifier('CommandAttr:'.$name.' model Sonos_'.$modelNumber);
		
		$SONOS_Client_SendQueue_Suspend = 0;
		SONOS_Log undef, 2, "SonosPlayer '$saveRoomName' is now updated";
		
		# AVTransport-Subscription
		if ($transportService) {
			$SONOS_TransportSubscriptions{$udn} = $transportService->subscribe(\&SONOS_ServiceCallback);
			if (defined($SONOS_TransportSubscriptions{$udn})) {
				SONOS_Log undef, 2, 'Service-subscribing successful with SID="'.$SONOS_TransportSubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_TransportSubscriptions{$udn}->timeout.'s"';
			} else {
				SONOS_Log undef, 1, 'Service-subscribing NOT successful';
			}
		} else {
			undef($SONOS_TransportSubscriptions{$udn});
			SONOS_Log undef, 1, 'Service-subscribing not possible due to missing TransportService';
		}
		
		# Rendering-Subscription, wenn eine untere oder obere Lautstärkegrenze angegeben wurde, und Lautstärke überhaupt geht
		if ($renderingService && (SONOS_Client_Data_Retreive($udn, 'attr', 'minVolume', -1) != -1 || SONOS_Client_Data_Retreive($udn, 'attr', 'maxVolume', -1) != -1 || SONOS_Client_Data_Retreive($udn, 'attr', 'minVolumeHeadphone', -1) != -1 || SONOS_Client_Data_Retreive($udn, 'attr', 'maxVolumeHeadphone', -1)  != -1 )) {
	  		$SONOS_RenderingSubscriptions{$udn} = $renderingService->subscribe(\&SONOS_RenderingCallback);
	  		$SONOS_ButtonPressQueue{$udn} = Thread::Queue->new();
	  		if (defined($SONOS_RenderingSubscriptions{$udn})) {
	  			SONOS_Log undef, 2, 'Rendering-Service-subscribing successful with SID="'.$SONOS_RenderingSubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_RenderingSubscriptions{$udn}->timeout.'s"';
	  		} else {
	  			SONOS_Log undef, 1, 'Rendering-Service-subscribing NOT successful';
	  		}
	    } else {
	    	undef($SONOS_RenderingSubscriptions{$udn});
	    }
    
		# Alarm-Subscription
		if ($alarmService && (SONOS_Client_Data_Retreive($udn, 'attr', 'getAlarms', 0) != 0)) {
			$SONOS_AlarmSubscriptions{$udn} = $alarmService->subscribe(\&SONOS_AlarmCallback);
			if (defined($SONOS_AlarmSubscriptions{$udn})) {
				SONOS_Log undef, 2, 'Alarm-Service-subscribing successful with SID="'.$SONOS_AlarmSubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_AlarmSubscriptions{$udn}->timeout.'s"';
			} else {
				SONOS_Log undef, 1, 'Alarm-Service-subscribing NOT successful';
			}
		} else {
			undef($SONOS_AlarmSubscriptions{$udn});
		}
		
		# ZoneGroupTopology-Subscription
		if ($zoneGroupTopologyService) {
			$SONOS_ZoneGroupTopologySubscriptions{$udn} = $zoneGroupTopologyService->subscribe(\&SONOS_ZoneGroupTopologyCallback);
			if (defined($SONOS_ZoneGroupTopologySubscriptions{$udn})) {
				SONOS_Log undef, 2, 'ZoneGroupTopology-Service-subscribing successful with SID="'.$SONOS_ZoneGroupTopologySubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_ZoneGroupTopologySubscriptions{$udn}->timeout.'s"';
			} else {
				SONOS_Log undef, 1, 'ZoneGroupTopology-Service-subscribing NOT successful';
			}
		} else {
			undef($SONOS_ZoneGroupTopologySubscriptions{$udn});
		}
		
		# DeviceProperties-Subscription
		if ($devicePropertiesService) {
			$SONOS_DevicePropertiesSubscriptions{$udn} = $devicePropertiesService->subscribe(\&SONOS_DevicePropertiesCallback);
			if (defined($SONOS_DevicePropertiesSubscriptions{$udn})) {
				SONOS_Log undef, 2, 'DeviceProperties-Service-subscribing successful with SID="'.$SONOS_DevicePropertiesSubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_DevicePropertiesSubscriptions{$udn}->timeout.'s"';
			} else {
				SONOS_Log undef, 1, 'DeviceProperties-Service-subscribing NOT successful';
			}
		} else {
			undef($SONOS_DevicePropertiesSubscriptions{$udn});
		}
		
		# AudioIn-Subscription
		if ($audioInService) {
			$SONOS_AudioInSubscriptions{$udn} = $audioInService->subscribe(\&SONOS_AudioInCallback);
			if (defined($SONOS_AudioInSubscriptions{$udn})) {
				SONOS_Log undef, 2, 'AudioIn-Service-subscribing successful with SID="'.$SONOS_AudioInSubscriptions{$udn}->SID.'" and Timeout="'.$SONOS_AudioInSubscriptions{$udn}->timeout.'s"';
			} else {
				SONOS_Log undef, 1, 'AudioIn-Service-subscribing NOT successful';
			}
		} else {
			undef($SONOS_AudioInSubscriptions{$udn});
		}
		
		SONOS_Log undef, 3, 'Discover: End of discover-event for "'.$roomName.'".';
	} elsif ($action eq 'deviceRemoved') {
		my $udn = $device->UDN;
		$udn =~ s/.*?://i;
		$udn .= '_MR';
		
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'presence', 'disappeared');
		SONOS_Log undef, 2, "Device '$udn' removed. Do nothing special here, cause all is done in another way..."; 
	} 
	
	return 0;
}

########################################################################################
#
#  SONOS_IsAlive - Checks if the given Device is alive or not and triggers the proper event if status changed
#
# Parameter $udn = UDN of the Device in short-form (e.g. RINCON_000E5828D0F401400_MR)
#
########################################################################################
sub SONOS_IsAlive($) {
	my ($udn) = @_;
	
	SONOS_Log $udn, 4, "IsAlive-Event UDN=$udn";
	my $result = 1;
	my $doDeleteProxyObjects = 0;
	
	$SONOS_Client_SendQueue_Suspend = 1;

	my $location = SONOS_Client_Data_Retreive($udn, 'reading', 'location', '');
	if ($location) {
		SONOS_Log $udn, 5, "Location: $location";
		my $host = ($1) if ($location =~ m/http:\/\/(.*?):/);
		
		my $pingType = $SONOS_Client_Data{pingType};
		return 1 if (lc($pingType) eq 'none');
		if ($pingType ~~ @SONOS_PINGTYPELIST) {
			SONOS_Log $udn, 5, "PingType: $pingType";
		} else {
			SONOS_Log $udn, 1, "Wrong pingType given for '$udn': '$pingType'. Choose one of '".join(', ', @SONOS_PINGTYPELIST)."'";
			$pingType = $SONOS_DEFAULTPINGTYPE;
		}
	
		my $ping = Net::Ping->new($pingType, 1);
		if ($ping->ping($host)) {
			# Alive
			SONOS_Log $udn, 4, "$host is alive";
			$result = 1;
			
			# IsAlive-Negativ-Counter zurücksetzen
			$SONOS_Thread_IsAlive_Counter{$host} = 0;
		} else {
			# Not Alive
			$SONOS_Thread_IsAlive_Counter{$host}++;
			
			if ($SONOS_Thread_IsAlive_Counter{$host} > $SONOS_Thread_IsAlive_Counter_MaxMerci) {
				SONOS_Log $udn, 3, "$host is REALLY NOT alive (out of merci maxlevel '".$SONOS_Thread_IsAlive_Counter_MaxMerci.'\')';
				$result = 0;
				
				SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'presence', 'disappeared');
				SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'state', 'disappeared');
				$doDeleteProxyObjects = 1;
			} else {
				SONOS_Log $udn, 3, "$host is NOT alive, but in merci level ".$SONOS_Thread_IsAlive_Counter{$host}.'/'.$SONOS_Thread_IsAlive_Counter_MaxMerci.'.';
			}
		}
		$ping->close();
	}
	
	$SONOS_Client_SendQueue_Suspend = 0;
	
	# Jetzt, wo das Reading dazu auch gesetzt wurde, hier ausführen
	if ($doDeleteProxyObjects) {
		my %data;
		$data{WorkType} = 'deleteProxyObjects';
		$data{UDN} = $udn;
		my @params = ();
		$data{Params} = \@params;
		
		$SONOS_ComObjectTransportQueue->enqueue(\%data);
		
		# Signalhandler aufrufen, wenn er nicht sowieso noch läuft...
		if (defined(threads->object($SONOS_Thread))) {
			threads->object($SONOS_Thread)->kill('HUP') if ($SONOS_ComObjectTransportQueue->pending() == 1);
		}
	}
	
	return $result;
}

########################################################################################
#
#  SONOS_DeleteProxyObjects - Deletes all references to the proxy objects of the given zoneplayer
#
# Parameter $name = The name of zoneplayerdevice
#
########################################################################################
sub SONOS_DeleteProxyObjects($) {
	my ($udn) = @_;
	
	SONOS_Log $udn, 2, "DeleteProxyObjects for '$udn'";
	
	delete $SONOS_AVTransportControlProxy{$udn};
	delete $SONOS_RenderingControlProxy{$udn};
	delete $SONOS_ContentDirectoryControlProxy{$udn};
	delete $SONOS_AlarmClockControlProxy{$udn};
	delete $SONOS_AudioInProxy{$udn};
	delete $SONOS_DevicePropertiesProxy{$udn};
	delete $SONOS_GroupManagementProxy{$udn};
	delete $SONOS_MusicServicesProxy{$udn};
	delete $SONOS_ZoneGroupTopologyProxy{$udn};
	
	delete $SONOS_TransportSubscriptions{$udn};
	
	delete $SONOS_RenderingSubscriptions{$udn};
	
	SONOS_Log $udn, 2, "DeleteProxyObjects DONE for '$udn'";
}

########################################################################################
#
#  SONOS_GetReadingsToCurrentHash - Get all neccessary readings from named device
#
# Parameter $name = The name of the player-device
#
########################################################################################
sub SONOS_GetReadingsToCurrentHash($$) {
	my ($name, $emptyCurrent) = @_;
	
	my %current;
	
	if ($emptyCurrent) {
		# Empty Values for Current Track Readings
		$current{TransportState} = 'ERROR';
		$current{Shuffle} = 0;
		$current{Repeat} = 0;
		$current{CrossfadeMode} = 0;
		$current{NumberOfTracks} = '';
		$current{Track} = '';
		$current{TrackURI} = '';
		$current{TrackDuration} = '';
		$current{TrackPosition} = '';
		$current{TrackMetaData} = '';
		$current{AlbumArtURI} = '';
		$current{AlbumArtURL} = '';
		$current{Title} = '';
		$current{Artist} = '';
		$current{Album} = '';
		$current{OriginalTrackNumber} = '';
		$current{AlbumArtist} = '';
		$current{Sender} = '';
		$current{SenderCurrent} = '';
		$current{SenderInfo} = '';
		$current{nextTrackDuration} = '';
		$current{nextTrackURI} = '';
		$current{nextAlbumArtURI} = '';
		$current{nextAlbumArtURL} = '';
		$current{nextTitle} = '';
		$current{nextArtist} = '';
		$current{nextAlbum} = '';
		$current{nextAlbumArtist} = '';
		$current{nextOriginalTrackNumber} = '';
		$current{InfoSummarize1} = '';
		$current{InfoSummarize2} = '';
		$current{InfoSummarize3} = '';
		$current{InfoSummarize4} = '';
		$current{StreamAudio} = 0;
		$current{NormalAudio} = 0;
	} else {
		# Insert normal Current Track Readings
		$current{TransportState} = ReadingsVal($name, 'transportState', 'ERROR');
		$current{Shuffle} = ReadingsVal($name, 'Shuffle', 0);
		$current{Repeat} = ReadingsVal($name, 'Repeat', 0);
		$current{CrossfadeMode} = ReadingsVal($name, 'CrossfadeMode', 0);
		$current{NumberOfTracks} = ReadingsVal($name, 'numberOfTracks', '');
		$current{Track} = ReadingsVal($name, 'currentTrack', '');
		$current{TrackURI} = ReadingsVal($name, 'currentTrackURI', '');
		$current{TrackDuration} = ReadingsVal($name, 'currentTrackDuration', '');
		$current{TrackPosition} = ReadingsVal($name, 'currentTrackPosition', '');
		#$current{TrackMetaData} = '';
		$current{AlbumArtURI} = ReadingsVal($name, 'currentAlbumArtURI', '');
		$current{AlbumArtURL} = ReadingsVal($name, 'currentAlbumArtURL', '');
		$current{Title} = ReadingsVal($name, 'currentTitle', '');
		$current{Artist} = ReadingsVal($name, 'currentArtist', '');
		$current{Album} = ReadingsVal($name, 'currentAlbum', '');
		$current{OriginalTrackNumber} = ReadingsVal($name, 'currentOriginalTrackNumber', '');
		$current{AlbumArtist} = ReadingsVal($name, 'currentAlbumArtist', '');
		$current{Sender} = ReadingsVal($name, 'currentSender', '');
		$current{SenderCurrent} = ReadingsVal($name, 'currentSenderCurrent', '');
		$current{SenderInfo} = ReadingsVal($name, 'currentSenderInfo', '');
		$current{nextTrackDuration} = ReadingsVal($name, 'nextTrackDuration', '');
		$current{nextTrackURI} = ReadingsVal($name, 'nextTrackURI', '');
		$current{nextAlbumArtURI} = ReadingsVal($name, 'nextAlbumArtURI', '');
		$current{nextAlbumArtURL} = ReadingsVal($name, 'nextAlbumArtURL', '');
		$current{nextTitle} = ReadingsVal($name, 'nextTitle', '');
		$current{nextArtist} = ReadingsVal($name, 'nextArtist', '');
		$current{nextAlbum} = ReadingsVal($name, 'nextAlbum', '');
		$current{nextAlbumArtist} = ReadingsVal($name, 'nextAlbumArtist', '');
		$current{nextOriginalTrackNumber} = ReadingsVal($name, 'nextOriginalTrackNumber', '');
		$current{InfoSummarize1} = ReadingsVal($name, 'infoSummarize1', '');
		$current{InfoSummarize2} = ReadingsVal($name, 'infoSummarize2', '');
		$current{InfoSummarize3} = ReadingsVal($name, 'infoSummarize3', '');
		$current{InfoSummarize4} = ReadingsVal($name, 'infoSummarize4', '');
		$current{StreamAudio} = ReadingsVal($name, 'currentStreamAudio', 0);
		$current{NormalAudio} = ReadingsVal($name, 'currentNormalAudio', 0);
	}
  
	# Insert Variables scanned during Device Detection or other events (for simple Replacing-Option of InfoSummarize)
	$current{Volume} = ReadingsVal($name, 'Volume', 0);
	$current{Mute} = ReadingsVal($name, 'Mute', 0);
	$current{Balance} = ReadingsVal($name, 'Balance', 0);
	$current{HeadphoneConnected} = ReadingsVal($name, 'HeadphoneConnected', 0);
	$current{SleepTimer} = ReadingsVal($name, 'SleepTimer', '');
	$current{AlarmRunning} = ReadingsVal($name, 'AlarmRunning', '');
	$current{AlarmRunningID} = ReadingsVal($name, 'AlarmRunningID', '');
	$current{Presence} = ReadingsVal($name, 'presence', '');
	$current{RoomName} = ReadingsVal($name, 'roomName', '');
	$current{SaveRoomName} = ReadingsVal($name, 'saveRoomName', '');
	$current{PlayerType} = ReadingsVal($name, 'playerType', '');
	$current{Location} = ReadingsVal($name, 'location', '');
	$current{SoftwareRevision} = ReadingsVal($name, 'softwareRevision', '');
	$current{SerialNum} = ReadingsVal($name, 'serialNum', '');
	$current{ZoneGroupID} = ReadingsVal($name, 'ZoneGroupID', '');
	$current{ZoneGroupName} = ReadingsVal($name, 'ZoneGroupName', '');
	$current{ZonePlayerUUIDsInGroup} = ReadingsVal($name, 'ZonePlayerUUIDsInGroup', '');
	
	return %current;
}

########################################################################################
#
#  SONOS_ServiceCallback - Service-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_ServiceCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'Transport-Event receive error: SonosPlayer not found; Searching for \''.$service->base.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 4, "Transport-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received Transport-Event for Zone "'.$name.'".';
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:AVTransport:1') {
		SONOS_Log $udn, 1, 'Transport-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	# Check if the Variable called LastChange exists
	if (not defined($properties{LastChange})) {
		SONOS_Log $udn, 1, 'Transport-Event receive error: Property \'LastChange\' does not exists!';
		return;
	}
  
	SONOS_Log $udn, 4, "Transport-Event: All correct with this service-call till now. UDN='uuid:$udn'";
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Determine the base URLs for downloading things from player
	my $groundURL = ($1) if ($service->base =~ m/(http:\/\/.*?:\d+)/i);
	SONOS_Log $udn, 4, "Transport-Event: GroundURL: $groundURL";
  
	# Variablen initialisieren
	SONOS_Client_Notifier('GetReadingsToCurrentHash:'.$udn.':1');
	
	my $currentValue;

	# Die Daten wurden uns HTML-Kodiert übermittelt... diese Entities nun in Zeichen umwandeln, da sonst die regulären Ausdrücke ziemlich unleserlich werden...
	$properties{LastChangeDecoded} = decode_entities($properties{LastChange});
	$properties{LastChangeDecoded} =~ s/[\r\n]//isg; # Komischerweise können hier unmaskierte Newlines auftauchen... wegmachen

	# Verarbeitung starten	
	SONOS_Log $udn, 4, 'Transport-Event: LastChange: '.$properties{LastChangeDecoded};
	
	
	# Bulkupdate hier starten...
	#SONOS_Client_Notifier('ReadingsBeginUpdate:'.$udn);
	
	# Check, if this is a SleepTimer-Event
	my $sleepTimerVersion = $1 if ($properties{LastChangeDecoded} =~ m/<r:SleepTimerGeneration val="(.*?)"\/>/i);
	if (defined($sleepTimerVersion) && $sleepTimerVersion ne SONOS_Client_Data_Retreive($udn, 'reading', 'SleepTimerVersion', '')) {
		# Variablen neu initialisieren, und die Original-Werte wieder mit reinholen
		SONOS_Client_Notifier('GetReadingsToCurrentHash:'.$udn.':0');
		
		# Neuer SleepTimer da!
		if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
			my $result = $SONOS_AVTransportControlProxy{$udn}->GetRemainingSleepTimerDuration();
			my $currentValue = $result->getValue('RemainingSleepTimerDuration');
			$currentValue = '' if (!defined($currentValue));
			
			# Wenn der Timer abgelaufen ist, wird nur ein Leerstring übergeben. Diesen durch das Wort off ersetzen.
			$currentValue = 'off' if ($currentValue eq '');
			
			SONOS_Client_Notifier('SetCurrent:SleepTimer:'.$currentValue);
			
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'SleepTimerVersion', ($result->getValue('CurrentSleepTimerGeneration') ? $result->getValue('CurrentSleepTimerGeneration') : ''));
		}
	}
	
	# Um einen XML-Parser zu vermeiden, werden hier einige reguläre Ausdrücke für die Ermittlung der Werte eingesetzt...
	# Transportstate ermitteln	
	if ($properties{LastChangeDecoded} =~ m/<TransportState val="(.*?)"\/>/i) {
		$currentValue = decode_entities($1);
		# Wenn der TransportState den neuen Wert 'Transitioning' hat, dann diesen auf Playing umsetzen, da das hier ausreicht.
		$currentValue = 'PLAYING' if $currentValue eq 'TRANSITIONING';
		SONOS_Client_Notifier('SetCurrent:TransportState:'.$currentValue);
	}
	
	# Wird hier gerade eine Alarm-Abspielung durchgeführt (oder beendet)?
	SONOS_Client_Notifier('SetCurrent:AlarmRunning:'.$1) if ($properties{LastChangeDecoded} =~ m/<r:AlarmRunning val="(.*?)"\/>/i);
	
	# Wenn ein Alarm läuft, dann zusätzliche Informationen besorgen, ansonsten das entsprechende Reading leeren
	if (defined($1) && $1 eq '1') {
		if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
			my $alarmID = $SONOS_AVTransportControlProxy{$udn}->GetRunningAlarmProperties(0)->getValue('AlarmID');
			SONOS_Client_Notifier('SetCurrent:AlarmRunningID:'.$alarmID);
		}
	} elsif (defined($1) && $1 eq '0') {
		SONOS_Client_Notifier('SetCurrent:AlarmRunningID:');
	}
	
	# Das nächste nur machen, wenn dieses Event die Track-Informationen auch enthält
	if ($properties{LastChangeDecoded} =~ m/<TransportState val=".*?"\/>/i) {
		# PlayMode ermitteln
		my $currentPlayMode = 'NORMAL';
		$currentPlayMode = $1 if ($properties{LastChangeDecoded} =~ m/<CurrentPlayMode.*?val="(.*?)".*?\/>/i);
		SONOS_Client_Notifier('SetCurrent:Shuffle:1') if ($currentPlayMode eq 'SHUFFLE' || $currentPlayMode eq 'SHUFFLE_NOREPEAT');
		SONOS_Client_Notifier('SetCurrent:Repeat:1') if ($currentPlayMode eq 'SHUFFLE' || $currentPlayMode eq 'REPEAT_ALL');
		
		# CrossfadeMode ermitteln
		SONOS_Client_Notifier('SetCurrent:CrossfadeMode:'.$1) if ($properties{LastChangeDecoded} =~ m/<CurrentCrossfadeMode.*?val="(\d+)".*?\/>/i);
		
		# Anzahl Tracknumber ermitteln
		SONOS_Client_Notifier('SetCurrent:NumberOfTracks:'.decode_entities($1)) if ($properties{LastChangeDecoded} =~ m/<NumberOfTracks val="(.*?)"\/>/i);
		
		# Current Tracknumber ermitteln
		SONOS_Client_Notifier('SetCurrent:Track:'.decode_entities($1)) if ($properties{LastChangeDecoded} =~ m/<CurrentTrack val="(.*?)"\/>/i);
		
		
		# Current TrackURI ermitteln
		my $currentTrackURI = SONOS_GetURIFromQueueValue($1) if ($properties{LastChangeDecoded} =~ m/<CurrentTrackURI val="(.*?)"\/>/i);
		SONOS_Client_Notifier('SetCurrent:TrackURI:'.$currentTrackURI);
		
		# Wenn es ein Spotify-Track ist, dann den Benutzernamen sichern, damit man diesen beim nächsten Export zur Verfügung hat
		if ($currentTrackURI =~ m/^x-sonos-spotify:/i) {
			my $enqueuedTransportMetaData = decode_entities($1) if ($properties{LastChangeDecoded} =~ m/r:EnqueuedTransportURIMetaData val="(.*?)"\/>/i);
			SONOS_Client_Notifier('ReadingsSingleUpdateIfChangedNoTrigger:undef:UserID_Spotify:'.uri_escape($1)) if ($enqueuedTransportMetaData =~ m/<desc .*?>(SA_.*?)<\/desc>/i);
		}
		
		# Wenn es ein Napster/Rhapsody-Track ist, dann den Benutzernamen sichern, damit man diesen beim nächsten Export zur Verfügung hat
		if ($currentTrackURI =~ m/^npsdy:/i) {
			my $enqueuedTransportMetaData = decode_entities($1) if ($properties{LastChangeDecoded} =~ m/r:EnqueuedTransportURIMetaData val="(.*?)"\/>/i);
			SONOS_Client_Notifier('ReadingsSingleUpdateIfChangedNoTrigger:undef:UserID_Napster:'.uri_escape($1)) if ($enqueuedTransportMetaData =~ m/<desc .*?>(SA_.*?)<\/desc>/i);
		}
		
		# Current Trackdauer ermitteln
		SONOS_Client_Notifier('SetCurrent:TrackDuration:'.decode_entities($1)) if ($properties{LastChangeDecoded} =~ m/<CurrentTrackDuration val="(.*?)"\/>/i);
		
		# Current Track Metadaten ermitteln
		my $currentTrackMetaData = decode_entities($1) if ($properties{LastChangeDecoded} =~ m/<CurrentTrackMetaData val="(.*?)"\/>/is);
		SONOS_Log $udn, 4, 'Transport-Event: CurrentTrackMetaData: '.$currentTrackMetaData;
		
		# Cover herunterladen (Infos dazu in den Track Metadaten)
		my $tempURIground = decode_entities($currentTrackMetaData);
		$tempURIground =~ s/%25/%/ig;
		
		my $tempURI = '';
		$tempURI = ($1) if ($tempURIground =~ m/<upnp:albumArtURI>(.*?)<\/upnp:albumArtURI>/i);
		SONOS_Client_Notifier('ProcessCover:'.$udn.':0:'.$tempURI.':'.$groundURL);
		
		# Auch hier den XML-Parser verhindern, und alles per regulärem Ausdruck ermitteln...
		if ($currentTrackMetaData =~ m/<dc:title>x-(sonosapi|rincon)-stream:.*?<\/dc:title>/) {
			# Wenn es ein Stream ist, dann muss da was anderes erkannt werden
			SONOS_Log $udn, 4, "Transport-Event: Stream erkannt!";
			SONOS_Client_Notifier('SetCurrent:StreamAudio:1');
					
			# Sender ermitteln (per SOAP-Request an den SonosPlayer)
			SONOS_Client_Notifier('SetCurrent:Sender:'.$1) if ($service->controlProxy()->GetMediaInfo(0)->getValue('CurrentURIMetaData') =~ m/<dc:title>(.*?)<\/dc:title>/i);
			
			# Sender-Läuft ermitteln
			SONOS_Client_Notifier('SetCurrent:SenderCurrent:'.$1) if ($currentTrackMetaData =~ m/<r:radioShowMd>(.*?),p\d{6}<\/r:radioShowMd>/i);
		  
			# Sendungs-Informationen ermitteln
			$currentValue = decode_entities($1) if ($currentTrackMetaData =~ m/<r:streamContent>(.*?)<\/r:streamContent>/i);
			# Wenn hier eine Buffering- oder Connecting-Konstante zurückkommt, dann durch vernünftigen Text ersetzen
			$currentValue = 'Verbindung herstellen...' if ($currentValue eq 'ZPSTR_CONNECTING');
			$currentValue = 'Wird gestartet...' if ($currentValue eq 'ZPSTR_BUFFERING');
			# Wenn hier RTL.it seine Infos liefert, diese zurechtschnippeln...
			$currentValue = '' if ($currentValue eq '<songInfo />');
			if ($currentValue =~ m/<class>Music<\/class>.*?<mus_art_name>(.*?)<\/mus_art_name>/i) {
				$currentValue = $1;
				$currentValue =~ s/\[e\]amp\[p\]/&/ig;
			}
			SONOS_Client_Notifier('SetCurrent:SenderInfo:'.encode_entities($currentValue));
		} else {
			SONOS_Log $udn, 4, "Transport-Event: Normal erkannt!";
			SONOS_Client_Notifier('SetCurrent:NormalAudio:1');
			
			my $currentArtist = '';
			if ($currentTrackURI =~ m/x-rincon:(RINCON_[\dA-Z]+)/) {
				# Gruppenwiedergabe feststellen, und dann andere Informationen anzeigen
				SONOS_Client_Notifier('SetCurrent:Album:'.SONOS_Client_Data_Retreive($1.'_MR', 'reading', 'roomName', $1));
				SONOS_Client_Notifier('SetCurrent:Title:Gruppenwiedergabe');
				SONOS_Client_Notifier('SetCurrent:Artist:');
			} elsif ($currentTrackURI =~ m/x-rincon-stream:(RINCON_[\dA-Z]+)/) {
				# LineIn-Wiedergabe feststellen, und dann andere Informationen anzeigen
				SONOS_Client_Notifier('SetCurrent:Album:'.SONOS_Client_Data_Retreive($1.'_MR', 'reading', 'roomName', $1));
				SONOS_Client_Notifier('SetCurrent:Title:'.SONOS_replaceSpecialStringCharacters(decode_entities($1))) if ($currentTrackMetaData =~ m/<dc:title>(.*?)<\/dc:title>/i);
				SONOS_Client_Notifier('SetCurrent:Artist:');
				
				SONOS_Client_Notifier('ProcessCover:'.$udn.':0:/fhem/sonos/cover/input_default.jpg:');
			} elsif ($currentTrackURI =~ m/x-sonos-htastream:(RINCON_[\dA-Z]+):spdif/) {
				# LineIn-Wiedergabe der Playbar feststellen, und dann andere Informationen anzeigen
				SONOS_Client_Notifier('SetCurrent:Album:'.SONOS_Client_Data_Retreive($1.'_MR', 'reading', 'roomName', $1));
				SONOS_Client_Notifier('SetCurrent:Title:SPDIF-Wiedergabe');
				SONOS_Client_Notifier('SetCurrent:Artist:');
				
				SONOS_Client_Notifier('ProcessCover:'.$udn.':0:/fhem/sonos/cover/input_tv.jpg:');
			} else {
				# Titel ermitteln
				SONOS_Client_Notifier('SetCurrent:Title:'.$1) if ($currentTrackMetaData =~ m/<dc:title>(.*?)<\/dc:title>/i);
				
				# Interpret ermitteln
				if ($currentTrackMetaData =~ m/<dc:creator>(.*?)<\/dc:creator>/i) {
					$currentArtist = decode_entities($1);
					SONOS_Client_Notifier('SetCurrent:Artist:'.encode_entities($currentArtist));
				}
				
				# Album ermitteln
				SONOS_Client_Notifier('SetCurrent:Album:'.$1) if ($currentTrackMetaData =~ m/<upnp:album>(.*?)<\/upnp:album>/i);
			} 
			
			# Original Tracknumber ermitteln
			SONOS_Client_Notifier('SetCurrent:OriginalTrackNumber:'.decode_entities($1)) if ($currentTrackMetaData =~ m/<upnp:originalTrackNumber>(.*?)<\/upnp:originalTrackNumber>/i);
			
			# Album Artist ermitteln
			$currentValue = decode_entities($1) if ($currentTrackMetaData =~ m/<r:albumArtist>(.*?)<\/r:albumArtist>/i);
			$currentValue = $currentArtist if ($currentValue eq '');
			SONOS_Client_Notifier('SetCurrent:AlbumArtist:'.encode_entities($currentValue));
		}
		
		# Next Track Metadaten ermitteln
		my $nextTrackMetaData = decode_entities($1) if ($properties{LastChangeDecoded} =~ m/<r:NextTrackMetaData val="(.*?)"\/>/i);
		SONOS_Log $udn, 4, 'Transport-Event: NextTrackMetaData: '.$nextTrackMetaData;
		
		SONOS_Client_Notifier('SetCurrent:nextTrackDuration:'.decode_entities($1)) if ($nextTrackMetaData =~ m/<res.*?duration="(.*?)".*?>/i);
		
		SONOS_Client_Notifier('SetCurrent:nextTrackURI:'.SONOS_GetURIFromQueueValue($1)) if ($properties{LastChangeDecoded} =~ m/<r:NextTrackURI val="(.*?)"\/>/i);
		
		$tempURIground = decode_entities($nextTrackMetaData);
		$tempURIground =~ s/%25/%/ig;
		
		$tempURI = '';
		$tempURI = ($1) if ($tempURIground =~ m/<upnp:albumArtURI>(.*?)<\/upnp:albumArtURI>/i);
		SONOS_Client_Notifier('ProcessCover:'.$udn.':1:'.$tempURI.':'.$groundURL);
		
		SONOS_Client_Notifier('SetCurrent:nextTitle:'.$1) if ($nextTrackMetaData =~ m/<dc:title>(.*?)<\/dc:title>/i);
		
		SONOS_Client_Notifier('SetCurrent:nextArtist:'.$1) if ($nextTrackMetaData =~ m/<dc:creator>(.*?)<\/dc:creator>/i);
		
		SONOS_Client_Notifier('SetCurrent:nextAlbum:'.$1) if ($nextTrackMetaData =~ m/<upnp:album>(.*?)<\/upnp:album>/i);
		
		SONOS_Client_Notifier('SetCurrent:nextAlbumArtist:'.$1) if ($nextTrackMetaData =~ m/<r:albumArtist>(.*?)<\/r:albumArtist>/i);
		
		SONOS_Client_Notifier('SetCurrent:nextOriginalTrackNumber:'.decode_entities($1)) if ($nextTrackMetaData =~ m/<upnp:originalTrackNumber>(.*?)<\/upnp:originalTrackNumber>/i);
	}
	
	# Current Trackposition ermitteln (durch Abfrage beim Player)
	if (SONOS_CheckProxyObject($udn, $SONOS_AVTransportControlProxy{$udn})) {
		my $trackPosition = $SONOS_AVTransportControlProxy{$udn}->GetPositionInfo(0)->getValue('RelTime');
		if ($trackPosition !~ /\d+:\d+:\d+/i) { # e.g. NOT_IMPLEMENTED
			$trackPosition = '0:00:00';
		}
		SONOS_Client_Notifier('SetCurrent:TrackPosition:'.$trackPosition);
	}
	
	# Trigger/Transfer the whole bunch and generate InfoSummarize
	SONOS_Client_Notifier('CurrentBulkUpdate:'.$udn);
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of Transport-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_RenderingCallback - Rendering-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_RenderingCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'Rendering-Event receive error: SonosPlayer not found; Searching for \''.$service->eventSubURL.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 3, "Rendering-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received Rendering-Event for Zone "'.$name.'".';
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:RenderingControl:1') {
		SONOS_Log $udn, 1, 'Rendering-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	# Check if the Variable called LastChange exists
	if (not defined($properties{LastChange})) {
		SONOS_Log $udn, 1, 'Rendering-Event receive error: Property \'LastChange\' does not exists!';
		return;
	}
  
	SONOS_Log $udn, 4, "Rendering-Event: All correct with this service-call till now. UDN='uuid:".$udn."'";
	
	# Die Daten wurden uns HTML-Kodiert übermittelt... diese Entities nun in Zeichen umwandeln, da sonst die regulären Ausdrücke ziemlich unleserlich werden...
	$properties{LastChangeDecoded} = decode_entities($properties{LastChange});
	
	SONOS_Log $udn, 4, 'Rendering-Event: LastChange: '.$properties{LastChangeDecoded};
	my $generateVolumeEvent = SONOS_Client_Data_Retreive($udn, 'attr', 'generateVolumeEvent', 0);

	# Mute?
	my $mute = SONOS_Client_Data_Retreive($udn, 'reading', 'Mute', 0);
	if ($properties{LastChangeDecoded} =~ m/<Mute.*?channel="Master".*?val="(\d+)".*?\/>/i) {
		SONOS_AddToButtonQueue($udn, 'M') if ($1 ne $mute);
		$mute = $1;
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Mute', $mute);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Mute', $mute);
		}
	}
	
	# Headphone?
	my $headphoneConnected = SONOS_Client_Data_Retreive($udn, 'reading', 'HeadphoneConnected', 0);
	if ($properties{LastChangeDecoded} =~ m/<HeadphoneConnected.*?val="(\d+)".*?\/>/i) {
		SONOS_AddToButtonQueue($udn, 'H') if ($1 ne $headphoneConnected);
		$headphoneConnected = $1;
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'HeadphoneConnected', $headphoneConnected);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'HeadphoneConnected', $headphoneConnected);
		}
	}
		
	
	# Balance ermitteln
	my $balance = SONOS_Client_Data_Retreive($udn, 'reading', 'Balance', 0);
	if ($properties{LastChangeDecoded} =~ m/<Volume.*?channel="LF".*?val="(\d+)".*?\/>/i) {
		my $volumeLeft = $1;
		my $volumeRight = $1 if ($properties{LastChangeDecoded} =~ m/<Volume.*?channel="RF".*?val="(\d+)".*?\/>/i);
		$balance = (-$volumeLeft) + $volumeRight if ($volumeLeft && $volumeRight);
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Balance', $balance);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Balance', $balance);
		}
	}
	
	
	# Volume ermitteln
	my $currentVolume = SONOS_Client_Data_Retreive($udn, 'reading', 'Volume', 0);
	if ($properties{LastChangeDecoded} =~ m/<Volume.*?channel="Master".*?val="(\d+)".*?\/>/i) {
		SONOS_AddToButtonQueue($udn, 'U') if ($1 > $currentVolume);
		SONOS_AddToButtonQueue($udn, 'D') if ($1 < $currentVolume);
		$currentVolume = $1 ;
	}
	
	# Loudness?
	my $loudness = SONOS_Client_Data_Retreive($udn, 'reading', 'Loudness', 0);
	if ($properties{LastChangeDecoded} =~ m/<Loudness.*?channel="Master".*?val="(\d+)".*?\/>/i) {
		$loudness = $1;
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Loudness', $loudness);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Loudness', $loudness);
		}
	}
	
	# Bass?
	my $bass = SONOS_Client_Data_Retreive($udn, 'reading', 'Bass', 0);
	if ($properties{LastChangeDecoded} =~ m/<Bass.*?val="([-]{0,1}\d+)".*?\/>/i) {
		$bass = $1;
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Bass', $bass);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Bass', $bass);
		}
	}
	
	# Treble?
	my $treble = SONOS_Client_Data_Retreive($udn, 'reading', 'Treble', 0);
	if ($properties{LastChangeDecoded} =~ m/<Treble.*?val="([-]{0,1}\d+)".*?\/>/i) {
		$treble = $1;
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Treble', $treble);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Treble', $treble);
		}
	}
	
	
	SONOS_Log $udn, 4, "Rendering-Event: Current Values for '$name' ~ Volume: $currentVolume, HeadphoneConnected: $headphoneConnected, Bass: $bass, Treble: $treble, Balance: $balance, Loudness: $loudness, Mute: $mute";
	
	# Grenzen passend zum verwendeten Tonausgang ermitteln
	# Untere Grenze ermitteln
	my $key = 'minVolume'.($headphoneConnected ? 'Headphone' : '');
	my $minVolume = SONOS_Client_Data_Retreive($udn, 'attr', $key, 0);
	
	# Obere Grenze ermitteln
	$key = 'maxVolume'.($headphoneConnected ? 'Headphone' : '');
	my $maxVolume = SONOS_Client_Data_Retreive($udn, 'attr', $key, 100);
	
	SONOS_Log $udn, 4, "Rendering-Event: Current Borders for '$name' ~ minVolume: $minVolume, maxVolume: $maxVolume";
	
	
	# Fehlerhafte Attributangaben?
	if ($minVolume > $maxVolume) {
		SONOS_Log $udn, 0, 'Min-/MaxVolume check Error: MinVolume('.$minVolume.') > MaxVolume('.$maxVolume.'), using Headphones: '.$headphoneConnected.'!';
		return;
	}
	
	# Prüfungen und Aktualisierungen durchführen
	if (!$mute && ($minVolume > $currentVolume)) {
		# Grenzen prüfen: Zu Leise
		SONOS_Log $udn, 4, 'Volume to Low. Correct it to "'.$minVolume.'"';
		
		$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'Master', $minVolume);
	} elsif (!$mute && ($currentVolume > $maxVolume)) {
		# Grenzen prüfen: Zu Laut
		SONOS_Log $udn, 4, 'Volume to High. Correct it to "'.$maxVolume.'"'; 
		
		$SONOS_RenderingControlProxy{$udn}->SetVolume(0, 'Master', $maxVolume);
	} else {
		# Alles OK, nur im FHEM aktualisieren
		if ($generateVolumeEvent) {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'Volume', $currentVolume);
		} else {
			SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChangedNoTrigger', $udn, 'Volume', $currentVolume);
		}
		
		# Variablen initialisieren
		SONOS_Client_Notifier('GetReadingsToCurrentHash:'.$udn.':0');
		SONOS_Client_Notifier('CurrentBulkUpdate:'.$udn);
	}
	
	# ButtonQueue prüfen
	SONOS_CheckButtonQueue($udn);
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of Rendering-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_AddToButtonQueue - Adds the given Event-Name to the ButtonQueue
#
########################################################################################
sub SONOS_AddToButtonQueue($$) {
	my ($udn, $event) = @_;
	
	my $data = {Action => uc($event), Time => time()};
	$SONOS_ButtonPressQueue{$udn}->enqueue($data);
}

########################################################################################
#
#  SONOS_CheckButtonQueue - Checks ButtonQueue and triggers events if neccessary
#
########################################################################################
sub SONOS_CheckButtonQueue($) {
	my ($udn) = @_;
	
	my $eventDefinitions = SONOS_Client_Data_Retreive($udn, 'attr', 'buttonEvents', '');
	
	# Wenn keine Events definiert wurden, dann Queue einfach leeren und zurückkehren...
	# Das beschleunigt die Verarbeitung, da im allgemeinen keine (oder eher wenig) Events definiert werden.
	if (!$eventDefinitions) {
		$SONOS_ButtonPressQueue{$udn}->dequeue_nb(10); # Es können pro Rendering-Event im Normalfall nur 4 Elemente dazukommen...
		return;
	}

	my $maxElems = 0;
	while ($eventDefinitions =~ m/(\d+):([MHUD]+)/g) {
		$maxElems = SONOS_Max($maxElems, length($2));
		
		# Sind überhaupt ausreichend Events in der Queue, das dieses ButtonEvent ausgefüllt sein könnte?
		my $ok = $SONOS_ButtonPressQueue{$udn}->pending() >= length($2);
		
		# Prüfen, ob alle Events in der Queue der Reihenfolge des ButtonEvents entsprechen
		if ($ok) {
			for (my $i = 0; $i < length($2); $i++) {
				if ($SONOS_ButtonPressQueue{$udn}->peek($SONOS_ButtonPressQueue{$udn}->pending() - length($2) + $i)->{Action} ne substr($2, $i, 1)) {
					$ok = 0;
				}
			}
		}
		
		# Wenn die Kette stimmt, dann hier prüfen, ob die Maximalzeit eingehalten wurde, und dann u.U. das Event werfen...
		if ($ok) {
			if (time() - $SONOS_ButtonPressQueue{$udn}->peek($SONOS_ButtonPressQueue{$udn}->pending() - length($2))->{Time} <= $1) {
				# Event here...
				SONOS_Log $udn, 3, 'Generating ButtonEvent for Zone "'.$udn.'": '.$2.'.';
				SONOS_Client_Data_Refresh('ReadingsSingleUpdate', $udn, 'ButtonEvent', $2);
			}
		}
	}
	
	# Einträge, die "zu viele Elemente" her sind, wieder entfernen, da diese sowieso keine Berücksichtigung mehr finden werden
	if ($SONOS_ButtonPressQueue{$udn}->pending() > $maxElems) {
		$SONOS_ButtonPressQueue{$udn}->extract(0, $SONOS_ButtonPressQueue{$udn}->pending() - $maxElems); # Es können pro Rendering-Event im Normalfall nur 4 Elemente dazukommen...
	}
}

########################################################################################
#
#  SONOS_AlarmCallback - Alarm-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_AlarmCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'Alarm-Event receive error: SonosPlayer not found; Searching for \''.$service->base.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 3, "Alarm-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received Alarm-Event for Zone "'.$name.'".';
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:AlarmClock:1') {
		SONOS_Log $udn, 1, 'Alarm-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	# Check if the Variable called AlarmListVersion or DailyIndexRefreshTime exists
	if (!defined($properties{AlarmListVersion}) && !defined($properties{DailyIndexRefreshTime})) {
		return;
	}
  
	SONOS_Log $udn, 4, "Alarm-Event: All correct with this service-call till now. UDN='uuid:".$udn."'";
	
	# If a new AlarmListVersion is available
	my $alarmListVersion = SONOS_Client_Data_Retreive($udn, 'reading', 'AlarmListVersion', '~~');
	if (defined($properties{AlarmListVersion}) && ($properties{AlarmListVersion} ne $alarmListVersion)) {
		SONOS_Log $udn, 4, 'Set new Alarm-Data';
		# Retrieve new AlarmList
		my $result = $SONOS_AlarmClockControlProxy{$udn}->ListAlarms();
		
		my $currentAlarmList = $result->getValue('CurrentAlarmList');
		my %alarms = ();
		my @alarmIDs = ();
		while ($currentAlarmList =~ m/<Alarm (.*?)\/>/gi) {
			my $alarm = $1;
			
			# Nur die Alarme, die auch für diesen Raum gelten, reinholen...
			if ($alarm =~ m/RoomUUID="$udnShort"/i) {
				my $id = $1 if ($alarm =~ m/ID="(\d+)"/i);
				SONOS_Log $udn, 5, 'Alarm-Event: Alarm: '.SONOS_Stringify($alarm);
				
				push @alarmIDs, $id;
				
				$alarms{$id}{StartTime} = $1 if ($alarm =~ m/StartTime="(.*?)"/i);
				$alarms{$id}{Duration} = $1 if ($alarm =~ m/Duration="(.*?)"/i);
				$alarms{$id}{Recurrence_Once} = 0;
				$alarms{$id}{Recurrence_Monday} = 0;
				$alarms{$id}{Recurrence_Tuesday} = 0;
				$alarms{$id}{Recurrence_Wednesday} = 0;
				$alarms{$id}{Recurrence_Thursday} = 0;
				$alarms{$id}{Recurrence_Friday} = 0;
				$alarms{$id}{Recurrence_Saturday} = 0;
				$alarms{$id}{Recurrence_Sunday} = 0;
				$alarms{$id}{Enabled} = $1 if ($alarm =~ m/Enabled="(.*?)"/i);
				$alarms{$id}{RoomUUID} = $1 if ($alarm =~ m/RoomUUID="(.*?)"/i);
				$alarms{$id}{ProgramURI} = decode_entities($1) if ($alarm =~ m/ProgramURI="(.*?)"/i);
				$alarms{$id}{ProgramMetaData} = decode_entities($1) if ($alarm =~ m/ProgramMetaData="(.*?)"/i);
				$alarms{$id}{Shuffle} = 0;
				$alarms{$id}{Repeat} = 0;
				$alarms{$id}{Volume} = $1 if ($alarm =~ m/Volume="(.*?)"/i);
				$alarms{$id}{IncludeLinkedZones} = $1 if ($alarm =~ m/IncludeLinkedZones="(.*?)"/i);
				
				# PlayMode ermitteln...
				my $currentPlayMode = 'NORMAL';
				$currentPlayMode = $1 if ($alarm =~ m/PlayMode="(.*?)"/i);
				$alarms{$id}{Shuffle} = 1 if ($currentPlayMode eq 'SHUFFLE' || $currentPlayMode eq 'SHUFFLE_NOREPEAT');
				$alarms{$id}{Repeat} = 1 if ($currentPlayMode eq 'SHUFFLE' || $currentPlayMode eq 'REPEAT_ALL');
				
				# Recurrence ermitteln...
				my $currentRecurrence = $1 if ($alarm =~ m/Recurrence="(.*?)"/i);
				$alarms{$id}{Recurrence_Once} = 1 if ($currentRecurrence eq 'ONCE');
				$alarms{$id}{Recurrence_Monday} = 1 if ($currentRecurrence =~ m/^ON_\d*?1/i);
				$alarms{$id}{Recurrence_Tuesday} = 1 if ($currentRecurrence =~ m/^ON_\d*?2/i);
				$alarms{$id}{Recurrence_Wednesday} = 1 if ($currentRecurrence =~ m/^ON_\d*?3/i);
				$alarms{$id}{Recurrence_Thursday} = 1 if ($currentRecurrence =~ m/^ON_\d*?4/i);
				$alarms{$id}{Recurrence_Friday} = 1 if ($currentRecurrence =~ m/^ON_\d*?5/i);
				$alarms{$id}{Recurrence_Saturday} = 1 if ($currentRecurrence =~ m/^ON_\d*?6/i);
				$alarms{$id}{Recurrence_Sunday} = 1 if ($currentRecurrence =~ m/^ON_\d*?7/i);
				
				SONOS_Log $udn, 5, 'Alarm-Event: Alarm-Decoded: '.SONOS_Stringify(\%alarms);
			}
		}
		
		# Sets the approbriate Readings-Value
		$Data::Dumper::Indent = 0;
		# SONOS_Client_Notifier('SetAlarm:'.$udn.':'.$result->getValue('CurrentAlarmListVersion').';'.join(',', @alarmIDs).':'.Dumper(\%alarms));
		SONOS_Client_Notifier('ReadingsBeginUpdate:'.$udn);
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'AlarmList', Dumper(\%alarms));
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'AlarmListIDs', join(',', @alarmIDs));
		SONOS_Client_Data_Refresh('ReadingsBulkUpdateIfChanged', $udn, 'AlarmListVersion', $result->getValue('CurrentAlarmListVersion'));
		SONOS_Client_Notifier('ReadingsEndUpdate:'.$udn);
		$Data::Dumper::Indent = 2;
	}
	
	if (defined($properties{DailyIndexRefreshTime})) {
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'DailyIndexRefreshTime', $properties{DailyIndexRefreshTime});
	}
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of Alarm-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_ZoneGroupTopologyCallback - ZoneGroupTopology-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_ZoneGroupTopologyCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'ZoneGroupTopology-Event receive error: SonosPlayer not found; Searching for \''.$service->base.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 3, "ZoneGroupTopology-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received ZoneGroupTopology-Event for Zone "'.$name.'".';
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:ZoneGroupTopology:1') {
		SONOS_Log $udn, 1, 'ZoneGroupTopology-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	SONOS_Log $udn, 4, "ZoneGroupTopology-Event: All correct with this service-call till now. UDN='uuid:".$udn."'";
	
	# ZoneGroupState: Gesamtkonstellation
	my $zoneGroupState = '';
	if ($properties{ZoneGroupState}) {
		$zoneGroupState = decode_entities($1) if ($properties{ZoneGroupState} =~ m/(.*)/);
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', 'undef', 'ZoneGroupState', $zoneGroupState);
	}
	
	# ZonePlayerUUIDsInGroup: Welche Player befinden sich alle in der gleichen Gruppe wie ich?
	my $zonePlayerUUIDsInGroup = SONOS_Client_Data_Retreive($udn, 'reading', 'ZonePlayerUUIDsInGroup', '');
	if ($properties{ZonePlayerUUIDsInGroup}) {
		$zonePlayerUUIDsInGroup = $properties{ZonePlayerUUIDsInGroup};
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'ZonePlayerUUIDsInGroup', $zonePlayerUUIDsInGroup);
	}
	
	# ZoneGroupID: Welcher Gruppe gehöre ich aktuell an, und hat sich meine Aufgabe innerhalb der Gruppe verändert?
	my $zoneGroupID = SONOS_Client_Data_Retreive($udn, 'reading', 'ZoneGroupID', '');
	my $fieldType = SONOS_Client_Data_Retreive($udn, 'reading', 'fieldType', '');
	if ($zoneGroupState =~ m/.*(<ZoneGroup Coordinator="(RINCON_[0-9a-f]+)".*?>).*?(<(ZoneGroupMember|Satellite) UUID="$udnShort".*?(>|\/>))/is) {
		$zoneGroupID = $2;
		my $member = $3;
		
		my $topoType = '';
		# Ist dieser Player in einem ChannelMapSet (also einer Paarung) enthalten?
		if ($member =~ m/ChannelMapSet=".*?$udnShort:(.*?),(.*?)[;"]/is) {
			$topoType = '_'.$1;
		}
		
		# Ist dieser Player in einem HTSatChanMapSet (also einem Surround-System) enthalten?
		if ($member =~ m/HTSatChanMapSet=".*?$udnShort:(.*?)[;"]/is) {
			$topoType = '_'.$1;
			$topoType =~ s/,/_/g;
		}
		
		SONOS_Log undef, 4, 'Retrieved TopoType: '.$topoType;
		$fieldType = substr($topoType, 1) if ($topoType ne '');
	}
	SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'ZoneGroupID', $zoneGroupID.':__');
	SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'fieldType', $fieldType);
	
	# ZoneGroupName: Welchen Namen hat die aktuelle Gruppe?
	my $zoneGroupName = SONOS_Client_Data_Retreive($udn, 'reading', 'ZoneGroupName', '');
	if ($properties{ZoneGroupName}) {
		$zoneGroupName = $properties{ZoneGroupName};
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'ZoneGroupName', $zoneGroupName);
	}
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of ZoneGroupTopology-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_DevicePropertiesCallback - DeviceProperties-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_DevicePropertiesCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'DeviceProperties-Event receive error: SonosPlayer not found; Searching for \''.$service->base.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 3, "DeviceProperties-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received DeviceProperties-Event for Zone "'.$name.'".';
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:DeviceProperties:1') {
		SONOS_Log $udn, 1, 'DeviceProperties-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	SONOS_Log $udn, 4, "DeviceProperties-Event: All correct with this service-call till now. UDN='uuid:".$udn."'";
	
	# Raumname wurde angepasst?
	my $roomName = SONOS_Client_Data_Retreive($udn, 'reading', 'roomName', '');
	if (defined($properties{ZoneName}) && $properties{ZoneName} ne '') {
		$roomName = decode(SONOS_Client_Data_Retreive('undef', 'attr', 'characterDecoding', 'CP-1252'), $properties{ZoneName});
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'roomName', $roomName);
		
		my $saveRoomName = decode('UTF-8', $roomName);
		$saveRoomName =~ s/([äöüÄÖÜß])/SONOS_UmlautConvert($1)/eg; # Hier erstmal Umlaute 'schön' machen, damit dafür nicht '_' verwendet werden...
		$saveRoomName =~ s/[^a-zA-Z0-9]/_/g;
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'saveRoomName', $saveRoomName);
	}
	
	# Icon wurde angepasst?
	my $roomIcon = SONOS_Client_Data_Retreive($udn, 'reading', 'roomIcon', '');
	if (defined($properties{Icon}) && $properties{Icon} ne '') {
		$properties{Icon} =~ s/.*?:(.*)/$1/i;
		
		$roomIcon = $properties{Icon};
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'roomIcon', $roomIcon);
	}
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of DeviceProperties-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_AudioInCallback - AudioIn-Callback, 
#
# Parameter $service = Service-Representing Object
#						$properties = Properties, that have been changed in this event
#
########################################################################################
sub SONOS_AudioInCallback($$) {
	my ($service, %properties) = @_;
	
	my $udn = $SONOS_Locations{$service->base};
	my $udnShort = $1 if ($udn =~ m/(.*?)_MR/i);
	
	if (!$udn) {
		SONOS_Log undef, 1, 'AudioIn-Event receive error: SonosPlayer not found; Searching for \''.$service->base.'\'!';
		return;
	}
	
	my $name = SONOS_Client_Data_Retreive($udn, 'def', 'NAME', $udn);
	
	# If the Device is disabled, return here...
	if (SONOS_Client_Data_Retreive($udn, 'attr', 'disable', 0) == 1) {
		SONOS_Log $udn, 3, "AudioIn-Event: device '$name' disabled. No Events/Data will be processed!";
		return;
	}
	
	SONOS_Log $udn, 3, 'Event: Received AudioIn-Event for Zone "'.$name.'".';
	$SONOS_Client_SendQueue_Suspend = 1;
	
	# Check if the correct ServiceType
	if ($service->serviceType() ne 'urn:schemas-upnp-org:service:AudioIn:1') {
		SONOS_Log $udn, 1, 'AudioIn-Event receive error: Wrong Servicetype, was \''.$service->serviceType().'\'!';
		return;
	}
	
	SONOS_Log $udn, 4, "AudioIn-Event: All correct with this service-call till now. UDN='uuid:".$udn."'";
	
	# LineInConnected wurde angepasst?
	my $lineInConnected = SONOS_Client_Data_Retreive($udn, 'reading', 'LineInConnected', '');
	if (defined($properties{LineInConnected}) && $properties{LineInConnected} ne '') {
		$lineInConnected = $properties{LineInConnected};
		SONOS_Client_Data_Refresh('ReadingsSingleUpdateIfChanged', $udn, 'LineInConnected', $lineInConnected);
	}
	
	$SONOS_Client_SendQueue_Suspend = 0;
	SONOS_Log $udn, 3, 'Event: End of AudioIn-Event for Zone "'.$name.'".';
	
	return 0;
}

########################################################################################
#
#  SONOS_replaceSpecialStringCharacters - Replaces invalid Characters in Strings (like ") for FHEM-internal 
#
# Parameter text = The text, inside that has to be searched and replaced
#
########################################################################################
sub SONOS_replaceSpecialStringCharacters($) {
	my ($text) = @_;
	
	$text =~ s/"/'/g;
	
	return $text;
}

########################################################################################
#
#  SONOS_maskSpecialStringCharacters - Replaces invalid Characters in Strings (like ") for FHEM-internal 
#
# Parameter text = The text, inside that has to be searched and replaced
#
########################################################################################
sub SONOS_maskSpecialStringCharacters($) {
	my ($text) = @_;
	
	$text =~ s/"/\\"/g;
	
	return $text;
}

########################################################################################
#
#  SONOS_ProcessInfoSummarize - Process the InfoSummarize-Fields (XML-Alike Structure)
#  Example for Minimal neccesary structure:
#	 <NormalAudio></NormalAudio> <StreamAudio></StreamAudio>
#
#  Complex Example:
#  <NormalAudio><Artist prefix="(" suffix=")"/><Title prefix=" '" suffix="'" ifempty="[Keine Musikdatei]"/><Album prefix=" vom Album '" suffix="'"/></NormalAudio> <StreamAudio><Sender suffix=":"/><SenderCurrent prefix=" '" suffix="'"/><SenderInfo prefix=" - "/></StreamAudio>
# OR
#  <NormalAudio><TransportState/><InfoSummarize1 prefix=" => "/></NormalAudio> <StreamAudio><TransportState/><InfoSummarize1 prefix=" => "/></StreamAudio>
#
# Parameter name = The name of the SonosPlayer-Device
#						current = The Current-Values hashset
#						summarizeVariableName = The variable-name to process (e.g. "InfoSummarize1")
#
########################################################################################
sub SONOS_ProcessInfoSummarize($$$$) {
	my ($hash, $current, $summarizeVariableName, $bulkUpdate) = @_;

	if (($current->{$summarizeVariableName} = AttrVal($hash->{NAME}, 'generate'.$summarizeVariableName, '')) ne '') {
		# Only pick up the current Audio-Type-Part, if one is available...
		if ($current->{NormalAudio}) {
			$current->{$summarizeVariableName} = $1 if ($current->{$summarizeVariableName} =~ m/<NormalAudio>(.*?)<\/NormalAudio>/i);
		} else {
			$current->{$summarizeVariableName} = $1 if ($current->{$summarizeVariableName} =~ m/<StreamAudio>(.*?)<\/StreamAudio>/i);
		}
	
		# Replace placeholder with variables (list defined in 21_SONOSPLAYER ~ stateVariable)
		my $availableVariables = ($2) if (getAllAttr($hash->{NAME}) =~ m/(^|\s+)stateVariable:(.*?)(\s+|$)/);
		foreach (split(/,/, $availableVariables)) {
			$current->{$summarizeVariableName} = SONOS_ReplaceTextToken($current->{$summarizeVariableName}, $_, $current->{$_});
		}
	
		if ($bulkUpdate) {
			# Enqueue the event
			SONOS_readingsBulkUpdateIfChanged($hash, lcfirst($summarizeVariableName), $current->{$summarizeVariableName});
		} else {
			SONOS_readingsSingleUpdateIfChanged($hash, lcfirst($summarizeVariableName), $current->{$summarizeVariableName}, 1);
		}
	} else {
		if ($bulkUpdate) {
			# Enqueue the event
			SONOS_readingsBulkUpdateIfChanged($hash, lcfirst($summarizeVariableName), '');
		} else {
			SONOS_readingsSingleUpdateIfChanged($hash, lcfirst($summarizeVariableName), '', 1);
		}
	}
}

########################################################################################
#
#  SONOS_ReplaceTextToken - Search and replace any occurency of the given tokenName with the value of tokenValue
#
# Parameter text = The text, inside that has to be searched and replaced
#			tokenName = The name, that has to be searched for
#			tokenValue = The value, the has to be insert instead of tokenName
#
########################################################################################
sub SONOS_ReplaceTextToken($$$) {
	my ($text, $tokenName, $tokenValue) = @_;

	# Hier das Token mit Prefix, Suffix, Instead und IfEmpty ersetzen, wenn entsprechend vorhanden
	$text =~ s/<\s*?$tokenName(\s.*?\/|\/)>/SONOS_ReplaceTextTokenRegReplacer($tokenValue, $1)/eig;
	
	return $text;
}

########################################################################################
#
#  SONOS_ReplaceTextTokenRegReplacer - Internal procedure for replacing TagValues
#
# Parameter tokenValue = The value, the has to be insert instead of tokenName
#			$matcher = The values of the searched and found tag
#
########################################################################################
sub SONOS_ReplaceTextTokenRegReplacer($$) {
	my ($tokenValue, $matcher) = @_;
	
	my $emptyVal = SONOS_DealToken($matcher, 'emptyVal', '');

	return SONOS_ReturnIfNotEmpty($tokenValue, SONOS_DealToken($matcher, 'prefix', ''), $emptyVal).
			SONOS_ReturnIfEmpty($tokenValue, SONOS_DealToken($matcher, 'ifempty', $emptyVal), $emptyVal).
			SONOS_ReturnIfNotEmpty($tokenValue, SONOS_DealToken($matcher, 'instead', $tokenValue), $emptyVal).
			SONOS_ReturnIfNotEmpty($tokenValue, SONOS_DealToken($matcher, 'suffix', ''), $emptyVal);
}

########################################################################################
#
#  SONOS_DealToken - Extracts the content of the given tokenName if exist in checkText
#
# Parameter checkText = The text, that has to be search in
#			tokenName = The value, of which the content has to be returned
#
########################################################################################
sub SONOS_DealToken($$$) {
	my ($checkText, $tokenName, $emptyVal) = @_;
	
	my $returnText = $1 if($checkText =~ m/$tokenName\s*=\s*"(.*?)"/i);
	
	return $emptyVal if (not defined($returnText));
	return $returnText;
}

########################################################################################
#
#  SONOS_ReturnIfEmpty - Returns the second Parameter returnValue only, if the first Parameter checkText *is* empty
#
# Parameter checkText = The text, that has to be checked
#			returnValue = The value, the has to be returned
#
########################################################################################
sub SONOS_ReturnIfEmpty($$$) {
	my ($checkText, $returnValue, $emptyVal) = @_;
	
	return '' if not defined($returnValue);
	return $returnValue if ((not defined($checkText)) || $checkText eq $emptyVal);
	return '';
}

########################################################################################
#
#  SONOS_ReturnIfNotEmpty - Returns the second Parameter returnValue only, if the first Parameter checkText *is NOT* empty
#
# Parameter checkText = The text, that has to be checked
#			returnValue = The value, the has to be returned
#
########################################################################################
sub SONOS_ReturnIfNotEmpty($$$) {
	my ($checkText, $returnValue, $emptyVal) = @_;
	
	return '' if not defined($returnValue);
	return $returnValue if (defined($checkText) && $checkText ne $emptyVal);
	return '';
}

########################################################################################
#
#  SONOS_ImageDownloadTypeExtension - Gives the appropriate extension for the retrieved mimetype of the content of the given url
#
# Parameter url = The URL of the content 
#
########################################################################################
sub SONOS_ImageDownloadTypeExtension($) {
	my ($url) = @_;
	
	# Wenn Spotify, dann sendet der Zoneplayer keinen Mimetype, der ist dann immer JPG
	if ($url =~ m/x-sonos-spotify/) {
		return 'jpg';
	}
	
	# Wenn Napster, dann sendet der Zoneplayer keinen Mimetype, der ist dann immer JPG
	if ($url =~ m/npsdy/) {
		return 'jpg';
	}
	
	# Wenn Radio, dann sendet der Zoneplayer keinen Mimetype, der ist dann immer GIF
	if ($url =~ m/x-sonosapi-stream/) {
		return 'gif';
	}
	
	# Wenn Google Music oder Simfy, dann sendet der Zoneplayer keinen Mimetype, der ist dann immer JPG
	if ($url =~ m/x-sonos-http/) {
		return 'jpg';
	}
	
	# Server abfragen
	my ($content_type, $document_length, $modified_time, $expires, $server) = head($url);
	
	return 'ERROR' if (!defined($content_type) || ($content_type =~ m/<head>.*?<\/head>/));
	
	if ($content_type =~ m/png/) {
		return 'png';
	} elsif (($content_type =~ m/jpeg/) || ($content_type =~ m/jpg/)) {
		return 'jpg';
	} elsif ($content_type =~ m/gif/) {
		return 'gif';
	} else {
		$content_type =~ s/\//-/g;
		return $content_type;
	}
}

########################################################################################
#
#  SONOS_ImageDownloadMimeType - Retrieves the mimetype of the content of the given url
#
# Parameter url = The URL of the content 
#
########################################################################################
sub SONOS_ImageDownloadMimeType($) {
	my ($url) = @_;
	
	my ($content_type, $document_length, $modified_time, $expires, $server) = head($url);
	
	return $content_type;
}

########################################################################################
#
#  SONOS_DownloadReplaceIfChanged - Overwrites the file only if its changed
#
# Parameter url = The URL of the new file
#						dest = The local file-uri of the old file
#
# Return 1 = New file have been written
#				 0 = nothing happened, because the filecontents are identical
#
########################################################################################
sub SONOS_DownloadReplaceIfChanged($$) {
	my ($url, $dest) = @_;
	
	# Reading new file
	my $newFile = get $url;
	
	if (not defined($newFile)) {
		SONOS_Log undef, 4, 'Couldn\'t retrieve file "'.$url.'" via web. Trying to copy directly...';
		
		$newFile = SONOS_ReadFile($url);
		if (not defined($newFile)) {
			SONOS_Log undef, 4, 'Couldn\'t even copy file "'.$url.'" directly... exiting...';
			return 0;
		}
	}

	# Reading old file (if it exists)
	my $oldFile = SONOS_ReadFile($dest);
	$oldFile = '' if (!defined($oldFile));
	
	# compare those files, and overwrite old file, if it has to be changed
	if ($newFile ne $oldFile) {
		# Hier jetzt alle Dateien dieses Players entfernen, damit nichts überflüssiges rumliegt, falls sich die Endung geändert haben sollte
		if (($dest =~ m/(.*\.).*?/) && ($1 ne '')) {
			unlink(<$1*>);
		}
		
		# Hier jetzt die neue Datei herunterladen
		SONOS_Log undef, 4, "New filecontent for '$dest'!";
		if (defined(open IMGFILE, '>'.$dest)) {
			binmode IMGFILE ;
			print IMGFILE $newFile;
			close IMGFILE;
		} else {
			SONOS_Log undef, 1, "Error creating file $dest";
		}
		
		return 1;
	} else {
		SONOS_Log undef, 4, "Identical filecontent for '$dest'!";
		
		return 0;
	}
}

########################################################################################
#
#  SONOS_ReadFile - Read the content of the given filename
#
# Parameter $fileName = The filename, that has to be read
#
########################################################################################
sub SONOS_ReadFile($) {
	my ($fileName) = @_;

	if (-e $fileName) {
		my $fileContent = '';
		
		open IMGFILE, '<'.$fileName;
		binmode IMGFILE;
		while (<IMGFILE>){
			$fileContent .= $_;
		}
		close IMGFILE;
		
		return $fileContent;
	}
	
	return undef;
}

########################################################################################
#
#  SONOS_WriteFile - Write the content to the given filename
#
# Parameter $fileName = The filename, that has to be read
#
########################################################################################
sub SONOS_WriteFile($$) {
	my ($fileName, $data) = @_;
	
	open IMGFILE, '>'.$fileName;
	binmode IMGFILE;
	print IMGFILE $data;
	close IMGFILE;
}

########################################################################################
#
# SONOS_readingsBulkUpdateIfChanged - Wrapper for readingsBulkUpdate. Do only things if value has changed.
#
########################################################################################
sub SONOS_readingsBulkUpdateIfChanged($$$) {
	my ($hash, $readingName, $readingValue) = @_;
	
	return if (!defined($hash) || !defined($readingName) || !defined($readingValue));
	
	readingsBulkUpdate($hash, $readingName, $readingValue) if ReadingsVal($hash->{NAME}, $readingName, '~~ReAlLyNoTeQuAlSmArKeR~~') ne $readingValue;
}

########################################################################################
#
# SONOS_readingsEndUpdate - Wrapper for readingsEndUpdate.
#
########################################################################################
sub SONOS_readingsEndUpdate($$) {
	my ($hash, $doTrigger) = @_;
	
	readingsEndUpdate($hash, $doTrigger);
}

########################################################################################
#
# SONOS_readingsSingleUpdateIfChanged - Wrapper for readingsSingleUpdate. Do only things if value has changed.
#
########################################################################################
sub SONOS_readingsSingleUpdateIfChanged($$$$) {
	my ($hash, $readingName, $readingValue, $doTrigger) = @_;
	
	readingsSingleUpdate($hash, $readingName, $readingValue, $doTrigger) if ReadingsVal($hash->{NAME}, $readingName, '~~ReAlLyNoTeQuAlSmArKeR~~') ne $readingValue;
}

########################################################################################
#
# SONOS_RefreshIconsInFHEMWEB - Refreshs Iconcache in all FHEMWEB-Instances
#
########################################################################################
sub SONOS_RefreshIconsInFHEMWEB($) {
	my ($dir) = @_;
	$dir = $attr{global}{modpath}.$dir;
	
	foreach my $fhem_dev (sort keys %main::defs) { 
		if ($main::defs{$fhem_dev}{TYPE} eq 'FHEMWEB') {
			eval('fhem(\'set '.$main::defs{$fhem_dev}{NAME}.' rereadicons\');');
			last; # Die Icon-Liste ist global, muss also nur einmal neu gelesen werden
		}
	}
}

########################################################################################
#
# SONOS_getAllSonosplayerDevices - Retreives all available/defined Sonosplayer-Devices
#
########################################################################################
sub SONOS_getAllSonosplayerDevices() {
	my @devices = ();
	
	foreach my $fhem_dev (sort keys %main::defs) { 
		push @devices, $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'SONOSPLAYER');
	}
	
	return @devices;
}

########################################################################################
#
# SONOS_getDeviceDefHash - Retrieves the Def-Hash for the SONOS-Device (only one should exists, so this is OK)
#							or, if $devicename is given, the Def-Hash for the SONOSPLAYER with the given name.
#
# Parameter $devicename = SONOSPLAYER devicename to be searched for, undef if searching for SONOS instead
#
########################################################################################
sub SONOS_getDeviceDefHash($) {
	my ($devicename) = @_;
	
	if (defined($devicename)) {
		foreach my $fhem_dev (sort keys %main::defs) { 
			return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{NAME} eq $devicename);
		}
	} else {
		foreach my $fhem_dev (sort keys %main::defs) { 
			return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'SONOS');
		}
	}
	
	SONOS_Log undef, 1, "The Method 'SONOS_getDeviceDefHash' cannot find the FHEM-Device according to '$devicename'. This should not happen!";
}

########################################################################################
#
# SONOS_getSonosPlayerByUDN - Retrieves the Def-Hash for the SONOS-Device with the given UDN
#
########################################################################################
sub SONOS_getSonosPlayerByUDN($) {
	my ($udn) = @_;
	
	if (defined($udn)) {
		foreach my $fhem_dev (sort keys %main::defs) { 
			return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'SONOSPLAYER' && $main::defs{$fhem_dev}{UDN} eq $udn);
		}
	} else {
		foreach my $fhem_dev (sort keys %main::defs) { 
			return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'SONOS');
		}
	}
	
	SONOS_Log undef, 1, "The Method 'SONOS_getSonosPlayerByUDN' cannot find the FHEM-Device according to '$udn'. This should not happen!";
	
	return undef;
}

########################################################################################
#
# SONOS_getSonosPlayerByRoomName - Retrieves the Def-Hash for the SONOS-Device with the given RoomName
#
########################################################################################
sub SONOS_getSonosPlayerByRoomName($) {
	my ($roomName) = @_;
	
	foreach my $fhem_dev (sort keys %main::defs) { 
		return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'SONOSPLAYER' && $main::defs{$fhem_dev}{READINGS}{roomName}{VAL} eq $roomName);
	}
	
	SONOS_Log undef, 1, "The Method 'SONOS_getSonosPlayerByRoomName' cannot find the FHEM-Device according to '$roomName'. This should not happen!";
	
	return undef;
}

########################################################################################
#
#  SONOS_Undef - Implements UndefFn function
#
#  Parameter hash = hash of the master, name
#
########################################################################################
sub SONOS_Undef ($$) {
	my ($hash, $name) = @_;
	
	RemoveInternalTimer($hash);
	
	DevIo_SimpleWrite($hash, "disconnect\n", 0);
	DevIo_CloseDev($hash);
	
	return undef;
}

########################################################################################
#
#  SONOS_Delete - Implements DeleteFn function
#
#  Parameter hash = hash of the master, name
#
########################################################################################
sub SONOS_Delete($$) {
	my ($hash, $name) = @_;
	
	# Erst alle SonosPlayer-Devices löschen
	for my $player (SONOS_getAllSonosplayerDevices()) {
		CommandDelete(undef, $player->{NAME});
	}
	
	# Den SubProzess beenden
	# Wenn wir einen eigenen UPnP-Server gestartet haben, diesen hier auch wieder beenden, ansonsten nichts tun...
	if ($SONOS_StartedOwnUPnPServer) {
		# Da die Verbindung bereits durch UndefFn beendet wurde, muss sie hier neu aufgebaut werden, damit ich den Subprozess selbst beenden kann (vorher wurde nur die Verbindung beendet)...
		DevIo_OpenDev($hash, 1, undef);
		DevIo_SimpleWrite($hash, "shutdown\n", 0);
		DevIo_CloseDev($hash);
	}
	
	# Etwas warten...
	select(undef, undef, undef, 1);
	
	# Das Entfernen des Sonos-Devices selbst übernimmt Fhem
	return undef;
}

########################################################################################
#
#  SONOS_Shutdown - Implements ShutdownFn function
#
#  Parameter hash = hash of the master, name
#
########################################################################################
sub SONOS_Shutdown ($$) {
	my ($hash) = @_;
  
	RemoveInternalTimer($hash);
	
	# Wenn wir einen eigenen UPnP-Server gestartet haben, diesen hier auch wieder beenden, 
	# ansonsten nur die Verbindung kappen
	if ($SONOS_StartedOwnUPnPServer) {
		DevIo_SimpleWrite($hash, "shutdown\n", 0);
	} else {
		DevIo_SimpleWrite($hash, "disconnect\n", 0);
	}
	DevIo_CloseDev($hash);
	
	select(undef, undef, undef, 2);
	
	return undef;
}

########################################################################################
#
#  SONOS_isInList - Checks, at which position the given value is in the given list
# 									Results in -1 if element not found
#
########################################################################################
sub SONOS_posInList {
	my($search, @list) = @_;
	
	for (my $i = 0; $i <= $#list; $i++) {
		return $i if ($list[$i] && $search eq $list[$i]);
	}
	
	return -1;
}

########################################################################################
#
#  SONOS_isInList - Checks, if the given value is in the given list
#
########################################################################################
sub SONOS_isInList {
	my($search, @list) = @_;
	
	return 1 if SONOS_posInList($search, @list) >= 0;
	return 0;
}

########################################################################################
#
#  SONOS_Min - Retrieves the minimum of two values
#
########################################################################################
sub SONOS_Min($$) {
	$_[$_[0] > $_[1]]
}

########################################################################################
#
#  SONOS_Max - Retrieves the maximum of two values
#
########################################################################################
sub SONOS_Max($$) {
	$_[$_[0] < $_[1]]
}

########################################################################################
#
#  SONOS_GetRealPath - Retrieves the real (complete and absolute) path of the given file
#											 and converts all '\' to '/'
#
########################################################################################
sub SONOS_GetRealPath($) {
	my ($filename) = @_;
	my $realFilename = realpath($filename);
	
	$realFilename =~ s/\\/\//g;
	
	return $realFilename
}

########################################################################################
#
#  SONOS_GetAbsolutePath - Retreives the absolute path (without filename)
#
########################################################################################
sub SONOS_GetAbsolutePath($) {
	my ($filename) = @_;
	my $absFilename = SONOS_GetRealPath($filename);
	
	return substr($absFilename, 0, rindex($absFilename, '/'));
}

########################################################################################
#
#  SONOS_GetTimeFromString - Parse the given DateTime-String e.g. created by TimeNow().
#
########################################################################################
sub SONOS_GetTimeFromString($) {
	my ($timeStr) = @_;
	
	return 0 if (!defined($timeStr));
	
	eval {
		use Time::Local;
		if($timeStr =~ m/^(\d{4})-(\d{2})-(\d{2}) ([0-2]\d):([0-5]\d):([0-5]\d)$/) {
				return timelocal($6, $5, $4, $3, $2 - 1, $1 - 1900);
		}
	}
}

########################################################################################
#
#  SONOS_GetTimeString - Gets the String for the given time
#
########################################################################################
sub SONOS_GetTimeString($) {
	my ($time) = @_;
	
	my @t = localtime($time);
	
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

########################################################################################
#
#  SONOS_TimeNow - Same as FHEM.PL-TimeNow. Neccessary due to forked process...
#
########################################################################################
sub SONOS_TimeNow() {
	return SONOS_GetTimeString(time());
}

########################################################################################
#
#  SONOS_Log - Log to the normal Log-command with additional Infomations like Thread-ID and the prefix 'SONOS'
#
########################################################################################
sub SONOS_Log($$$) {
	my ($udn, $level, $text) = @_;
	
	if (defined($SONOS_ListenPort)) {
		if ($SONOS_Client_LogLevel >= $level) {
			my ($seconds, $microseconds) = gettimeofday();
			
			my @t = localtime($seconds);
			my $tim = sprintf("%04d.%02d.%02d %02d:%02d:%02d", $t[5]+1900,$t[4]+1,$t[3], $t[2],$t[1],$t[0]);
			
			if($SONOS_mseclog) {
				$tim .= sprintf(".%03d", $microseconds / 1000);
			}
			
			print "$tim $level: SONOS".threads->tid().": $text\n";
		}
	} else {
		my $hash = SONOS_getSonosPlayerByUDN($udn);
		
		eval {
			Log3 $hash->{NAME}, $level, 'SONOS'.threads->tid().': '.$text;
		};
		if ($@) {
			Log $level, 'SONOS'.threads->tid().': '.$text;
		}
	}
}

########################################################################################
########################################################################################
##
##  Start of Telnet-Server-Part for Sonos UPnP-Messages
##
##  If SONOS_ListenPort is defined, then we have to start a listening server
##
########################################################################################
########################################################################################
# Here starts the main-loop of the telnet-server
########################################################################################
if (defined($SONOS_ListenPort)) {
	$| = 1;
	
	my $runEndlessLoop = 1;
	my $lastRenewSubscriptionCheckTime = time();
	
	$SIG{'PIPE'} = 'IGNORE';
	$SIG{'CHLD'} = 'IGNORE';
	
	$SIG{'INT'} = sub {
		# Hauptschleife beenden
		$SONOS_Client_NormalQueueWorking = 0; 
		$runEndlessLoop = 0;
		
		# Sub-Threads beenden, sofern vorhanden
		if (($SONOS_Thread != -1) && defined(threads->object($SONOS_Thread))) {
			threads->object($SONOS_Thread)->kill('INT')->detach();
		}
		if (($SONOS_Thread_IsAlive != -1) && defined(threads->object($SONOS_Thread_IsAlive))) {
			threads->object($SONOS_Thread_IsAlive)->kill('INT')->detach();
		}
		if (($SONOS_Thread_PlayerRestore != -1) && defined(threads->object($SONOS_Thread_PlayerRestore))) {
			threads->object($SONOS_Thread_PlayerRestore)->kill('INT')->detach();
		}
	};
	
	my $sock;
	my $retryCounter = 10;
	do {
		eval {
			socket($sock, AF_INET, SOCK_STREAM, getprotobyname('tcp')) or die "Could not create socket: $!";
			bind($sock, sockaddr_in($SONOS_ListenPort, INADDR_ANY)) or die "Bind failed: $!";
			setsockopt($sock, SOL_SOCKET, SO_LINGER, pack("ii", 1, 0)) or die "Setsockopt failed: $!";
			listen($sock, 10);
		};
		if ($@) {
			SONOS_Log undef, 0, "Can't bind Port $SONOS_ListenPort: $@";
			SONOS_Log undef, 0, 'Retries left (wait 30s): '.--$retryCounter;
			
			if (!$retryCounter) {
				die 'Bind failed...';
			}
			
			select(undef, undef, undef, 30);
		}
	} while ($@);
	SONOS_Log undef, 1, "$0 is listening to Port $SONOS_ListenPort";
	
	# Accept incoming connections and talk to clients
	$SONOS_Client_Selector = IO::Select->new($sock);
	
	while ($runEndlessLoop) {
		# NormalQueueWorking wird für die Dauer einer Direkt-Wert-Anfrage deaktiviert, damit hier nicht blockiert und/oder zuviel weggelesen wird.
		if ($SONOS_Client_NormalQueueWorking) {
			# Das ganze blockiert eine kurze Zeit, um nicht 100% CPU-Last zu erzeugen
			# Das bedeutet aber auch, dass Sende-Vorgänge um maximal den Timeout-Wert verzögert werden
			my @ready = $SONOS_Client_Selector->can_read(0.1);
			
			# Falls wir hier auf eine Antwort reagieren würden, die gar nicht hierfür bestimmt ist, dann übergehen...
			next if (!$SONOS_Client_NormalQueueWorking);
			
			# Nachschauen, ob Subscriptions erneuert werden müssen
			if (time() - $lastRenewSubscriptionCheckTime > 1800) {
				$lastRenewSubscriptionCheckTime = time ();
				
				foreach my $udn (@{$SONOS_Client_Data{PlayerUDNs}}) {
					my %data;
					$data{WorkType} = 'renewSubscription';
					$data{UDN} = $udn;
					my @params = ();
					$data{Params} = \@params;
					
					$SONOS_ComObjectTransportQueue->enqueue(\%data);
					
					# Signalhandler aufrufen, wenn er nicht sowieso noch läuft...
					threads->object($SONOS_Thread)->kill('HUP') if ($SONOS_ComObjectTransportQueue->pending() == 1);
				}
			}
		 	
		 	# Alle Bereit-Schreibenden verarbeiten
		 	if ($SONOS_Client_SendQueue->pending() && !$SONOS_Client_SendQueue_Suspend) {
		 		my @receiver = $SONOS_Client_Selector->can_write(0);
		 		
		 		# Prüfen, ob überhaupt ein Empfänger bereit ist. Sonst würden Befehle verloren gehen...
		 		if (scalar(@receiver) > 0) {
			 		while ($SONOS_Client_SendQueue->pending()) {
						my $line = $SONOS_Client_SendQueue->dequeue();
						foreach my $so (@receiver) {
							send($so, $line, 0);
						}
					}
				}
			}
		 	
		 	# Alle Bereit-Lesenden verarbeiten
			foreach my $so (@ready) {
		 		if ($so == $sock) { # New Connection read
		 			my $client;
		 			
		 			my $addrinfo = accept($client, $sock);
					setsockopt($client, SOL_SOCKET, SO_LINGER, pack("ii", 1, 0));
		 			my ($port, $iaddr) = sockaddr_in($addrinfo);
		 			my $name = gethostbyaddr($iaddr, AF_INET);
		 			
		 			SONOS_Log undef, 1, "Connection accepted from $name:$port";
		 			
		 			# Von dort kommt die Anfrage, dort finde ich den Telnet-Port von Fhem :-)
		 			$SONOS_UseTelnetForQuestions_Host = $name;
		 			
		 			# Send Welcome-Message
		 			send($client, "'This is UPnP-Server calling'\r\n", 0);
		 			
		 			$SONOS_Client_Selector->add($client);
		 		} else { # Existing client calling
		 			my $inp = <$so>;
		 			
		 			if (defined($inp)) {
			 			# Abschließende Zeilenumbrüche abschnippeln
			 			$inp =~ s/[\r\n]*$//;
			 			
			 			# Consume and send evt. reply
			 			SONOS_Log undef, 5, "Received: '$inp'";
			 			SONOS_Client_ConsumeMessage($so, $inp);
			 		}
		 		}
		 	}
		 } else {
		 	# Wenn die Verarbeitung gerade unterbrochen sein soll, dann hier etwas warten, um keine 100% CPU-Last zu erzeugen
		 	select(undef, undef, undef, 0.5);
		 }
	}
	 
	SONOS_Log undef, 0, 'Das Lauschen auf der Schnittstelle wurde beendet. Prozess endet nun auch...';
	
	# Alle Handles entfernen und schliessen...
	for my $cl ($SONOS_Client_Selector->handles()) {
		$SONOS_Client_Selector->remove($cl);
		shutdown($cl, 2);
		close($cl);
	}
	
	# Prozess beenden...
	exit(0);
}

# Wird für den FHEM-Modulpart benötigt
1;

########################################################################################
# SONOS_Client_Thread_Notifier: Notifies all clients with the given message
########################################################################################
sub SONOS_Client_Notifier($) {
	my ($msg) = @_;
	$| = 1;
	
	state $setCurrentUDN;
	
	# Wenn hier ein SetCurrent ausgeführt werden soll, dann auch den lokalen Puffer aktualisieren
	if ($msg =~ m/SetCurrent:(.*?):(.*)/) {
		my $udnBuffer = ($setCurrentUDN eq 'undef') ? 'SONOS' : $setCurrentUDN;
		$SONOS_Client_Data{Buffer}->{$udnBuffer}->{$1} = $2;
	} elsif ($msg =~ m/GetReadingsToCurrentHash:(.*?):(.*)/) {
		$setCurrentUDN = $1;
	}
	
	# Immer ein Zeilenumbruch anfügen...
	$msg .= "\n" if (substr($msg, -1, 1) ne "\n");
	
	$SONOS_Client_SendQueue->enqueue($msg);
}

########################################################################################
# SONOS_Client_SendReceive: Send and receive messages
########################################################################################
sub SONOS_Client_SendReceive($) {
	my ($msg) = @_;
	
	# Immer ein Zeilenumbruch anfügen...
	$msg .= "\n" if (substr($msg, -1, 1) ne "\n");
	
	my $answer;
	$SONOS_Client_NormalQueueWorking = 0;
	select(undef, undef, undef, 0.1);
	
	my @sender = $SONOS_Client_Selector->can_write(0);
	foreach my $so (@sender) {
		send($so, $msg, 0);
		
		do { 
			select(undef, undef, undef, 0.1); 
			recv($so, $answer, 30000, 0);
		} while (!$answer);
	}
	
	select(undef, undef, undef, 0.1);
	$SONOS_Client_NormalQueueWorking = 1;
	
	return $answer;
}

########################################################################################
# SONOS_Client_SendReceiveTelnet: Send and receive messages
########################################################################################
sub SONOS_Client_SendReceiveTelnet($) {
	my ($msg) = @_;
	
	SONOS_Log undef, 4, "Telnet-Anfrage: $msg";
	
	eval {
		require Net::Telnet;
		my $socket = Net::Telnet->new(Timeout => 30);
		$socket->open(Host => $SONOS_UseTelnetForQuestions_Host, Port => $SONOS_UseTelnetForQuestions_Port);
		$socket->telnetmode(0);
		$socket->cmd();
		
		my @lines = $socket->cmd('{ SONOS_AnswerQuery("'.$msg.'") }');
		my $answer = $lines[0];
		$answer =~ s/[\r\n]*$//;
		
		$socket->close();
		
		return $answer;
	};
	if ($@) {
		SONOS_Log undef, 4, "Bei einer Telnet-Anfrage ist ein Fehler aufgetreten, es wird auf Normalanfrage umgestellt: $@";
		$SONOS_UseTelnetForQuestions = 0;
		return $3 if ($msg =~ m/Q.:(.*?):(.*?):(.*)/);
	}
	
	return "Error during processing: $msg";
}

########################################################################################
# SONOS_Client_AskAttribute: Asks FHEM for a AttributeValue according to the given Attributename
########################################################################################
sub SONOS_Client_AskAttribute($$$) {
	my ($udn, $name, $default) = @_;
	
	my $val;
	if ($SONOS_UseTelnetForQuestions) {
		$val = SONOS_Client_SendReceiveTelnet('QA:'.$udn.':'.$name.':'.$default);
	} else {
		$val = SONOS_Client_SendReceive('QA:'.$udn.':'.$name.':'.$default);
	}
	$val =~ s/[\r\n]*$//;
	$val = $1 if ($val =~ m/A:$udn:$name:(.*)/i);
	
	return $val;
}

########################################################################################
# SONOS_Client_AskReading: Asks FHEM for a ReadingValue according to the given Readingname
########################################################################################
sub SONOS_Client_AskReading($$$) {
	my ($udn, $name, $default) = @_;
	
	my $val;
	if ($SONOS_UseTelnetForQuestions) {
		$val = SONOS_Client_SendReceiveTelnet('QR:'.$udn.':'.$name.':'.$default);
	} else {
		$val = SONOS_Client_SendReceive('QR:'.$udn.':'.$name.':'.$default);
	}
	$val =~ s/[\r\n]*$//;
	$val = $1 if ($val =~ m/R:$udn:$name:(.*)/i);
	
	return $val;
}

########################################################################################
# SONOS_Client_AskDefinition: Asks FHEM for a DefinitionValue according to the given name
########################################################################################
sub SONOS_Client_AskDefinition($$$) {
	my ($udn, $name, $default) = @_;
	
	my $val;
	if ($SONOS_UseTelnetForQuestions) {
		$val = SONOS_Client_SendReceiveTelnet('QD:'.$udn.':'.$name.':'.$default);
	} else {
		$val = SONOS_Client_SendReceive('QD:'.$udn.':'.$name.':'.$default);
	}
	$val =~ s/[\r\n]*$//;
	$val = $1 if ($val =~ m/D:$udn:$name:(.*)/i);
	
	return $val;
}

########################################################################################
# SONOS_Client_Data_Retreive: Retrieves stored data, and calls AskXX if necessary
########################################################################################
sub SONOS_Client_Data_Retreive($$$$) {
	my ($udn, $reading, $name, $default) = @_;
	
	my $udnBuffer = ($udn eq 'undef') ? 'SONOS' : $udn;
	
	# Prüfen, ob die Anforderung überhaupt bedient werden darf
	if ($reading eq 'attr') {
		if (SONOS_posInList($name, @SONOS_PossibleAttributes) == -1) {
			SONOS_Log undef, 0, "Ungültige Attribut-Fhem-Informationsanforderung: $udnBuffer->$name.\nStoppe Prozess!";
			exit(1);
		}
	} elsif ($reading eq 'def') {
		if (SONOS_posInList($name, @SONOS_PossibleDefinitions) == -1) {
			SONOS_Log undef, 0, "Ungültige Definitions-Fhem-Informationsanforderung: $udnBuffer->$name.\nStoppe Prozess!";
			exit(1);
		}
	} else {
		if (SONOS_posInList($name, @SONOS_PossibleReadings) == -1) {
			SONOS_Log undef, 0, "Ungültige Reading-Fhem-Informationsanforderung: $udnBuffer->$name.\nStoppe Prozess!";
			exit(1);
		}
	}
	
	# Anfrage zulässig, also ausliefern...
	if (defined($SONOS_Client_Data{Buffer}->{$udnBuffer}) && defined($SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name})) {
		SONOS_Log undef, 4, "SONOS_Client_Data_Retreive($udnBuffer, $reading, $name, $default) -> ".$SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name};
		return $SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name};
	} else {
		SONOS_Log undef, 4, "SONOS_Client_Data_Retreive($udnBuffer, $reading, $name, $default) -> DEFAULT";
		return $default;
	}
	
	##################################################
	# Alter Mechanismus mit Anfrage an Fhem...
	#my $result = do { if (defined($SONOS_Client_Data{Buffer}->{$udnBuffer}) && defined($SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name})) { 
	#			$SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name} 
	#		} else { 
	#			if ($reading eq 'attr') { 
	#				SONOS_Client_AskAttribute($udn, $name, $default); 
	#			} elsif ($reading eq 'def') {
	#				SONOS_Client_AskDefinition($udn, $name, $default); 
	#			} else { 
	#				SONOS_Client_AskReading($udn, $name, $default); 
	#			} 
	#		} 
	#	};
	#$SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name} = $result;
	#
	#return $result;
}

########################################################################################
# SONOS_Client_Data_Refresh: Send data and refreshs buffer
########################################################################################
sub SONOS_Client_Data_Refresh($$$$) {
	my ($sendCommand, $udn, $name, $value) = @_;
	
	my $udnBuffer = ($udn eq 'undef') ? 'SONOS' : $udn;
	
	$SONOS_Client_Data{Buffer}->{$udnBuffer}->{$name} = $value;
	if ($sendCommand && ($sendCommand ne '')) {
		SONOS_Client_Notifier($sendCommand.':'.$udn.':'.$name.':'.$value);
	}
}

########################################################################################
# SONOS_Client_ConsumeMessage: Consumes the given message and give an evt. return
########################################################################################
sub SONOS_Client_ConsumeMessage($$) {
	my ($client, $msg) = @_;
	
	if (lc($msg) eq 'disconnect' || lc($msg) eq 'shutdown') {
		SONOS_Log undef, 3, "Disconnecting client and shutdown server..." if (lc($msg) eq 'shutdown');
		SONOS_Log undef, 3, "Disconnecting client..." if (lc($msg) ne 'shutdown');
		
		$SONOS_Client_Selector->remove($client);
		
		if ($SONOS_Thread != -1) {
			my $thr = threads->object($SONOS_Thread);
			
			if ($thr) {
				SONOS_Log undef, 3, 'Trying to kill Sonos_Thread...';
				$thr->kill('INT')->detach();
			} else {
				SONOS_Log undef, 3, 'Sonos_Thread is already killed!';
			}
		}
		if ($SONOS_Thread_IsAlive != -1) {
			my $thr = threads->object($SONOS_Thread_IsAlive);
			
			if ($thr) {
				SONOS_Log undef, 3, 'Trying to kill IsAlive_Thread...';
				$thr->kill('INT')->detach();
			} else {
				SONOS_Log undef, 3, 'IsAlive_Thread is already killed!';
			}
		}
		if ($SONOS_Thread_PlayerRestore != -1) {
			my $thr = threads->object($SONOS_Thread_PlayerRestore);
			
			if ($thr) {
				SONOS_Log undef, 3, 'Trying to kill PlayerRestore_Thread...';
				$thr->kill('INT')->detach();
			} else {
				SONOS_Log undef, 3, 'PlayerRestore_Thread is already killed!';
			}
		}
		
		shutdown($client, 2);
		close($client);
		
		threads->self()->kill('INT') if (lc($msg) eq 'shutdown');
	} elsif (lc($msg) eq 'hello') {
		send($client, "OK\r\n", 0);
	} elsif (lc($msg) eq 'goaway') {
		$SONOS_Client_Selector->remove($client);
		shutdown($client, 2);
		close($client);
	} elsif ($msg =~ m/SetData:(.*?):(.*?):(.*?):(.*?):(.*)/i) {
		$SONOS_Client_Data{SonosDeviceName} = $1;
		$SONOS_Client_LogLevel = $2;
		$SONOS_Client_Data{pingType} = $3;
		
		my @names = split(/,/, $4);
		$SONOS_Client_Data{PlayerNames} = shared_clone(\@names);
		
		my @udns = split(/,/, $5);
		$SONOS_Client_Data{PlayerUDNs} = shared_clone(\@udns);
		
		my @playeralive = ();
		$SONOS_Client_Data{PlayerAlive} = shared_clone(\@playeralive);
		
		my %player = ();
		$SONOS_Client_Data{Buffer} = shared_clone(\%player);
		push @udns, 'SONOS';
		foreach my $elem (@udns) {
			my %elemValues = ();
			$SONOS_Client_Data{Buffer}->{$elem} = shared_clone(\%elemValues);
		}
	} elsif ($msg =~ m/SetValues:(.*?):(.*)/i) {
		my $deviceName = $1;
		my $deviceValues = $2;
		my %elemValues = ();
		
		# Werte aus der Übergabe belegen
		foreach my $elem (split(/\|/, $deviceValues)) { 
			if ($elem =~ m/(.*?)=(.*)/) {
				$elemValues{$1} = uri_unescape($2);
			}
		}
		 
		$SONOS_Client_Data{Buffer}->{$deviceName} = shared_clone(\%elemValues);
	} elsif ($msg =~ m/DoWork:(.*?):(.*?):(.*)/i) {
		my %data;
		$data{WorkType} = $2;
		$data{UDN} = $1;
		
		if (defined($3)) {
			my @params = split(/,/, $3);
			$data{Params} = \@params;
		} else {
			my @params = ();
			$data{Params} = \@params;
		}
		
		# Auf die Queue legen wenn Thread läuft und Signalhandler aufrufen, wenn er nicht sowieso noch läuft...
		if ($SONOS_Thread != -1) {
			$SONOS_ComObjectTransportQueue->enqueue(\%data);
			threads->object($SONOS_Thread)->kill('HUP') if ($SONOS_ComObjectTransportQueue->pending() == 1);
		}
	} elsif (lc($msg) eq 'startthread') {
		# Discover-Thread
		$SONOS_Thread = threads->create(\&SONOS_Discover)->tid();
		
		# IsAlive-Checker-Thread
		if (lc($SONOS_Client_Data{pingType}) ne 'none') {
			$SONOS_Thread_IsAlive = threads->create(\&SONOS_Client_IsAlive)->tid();
		}
		
		# Playerrestore-Thread
		$SONOS_Thread_PlayerRestore = threads->create(\&SONOS_RestoreOldPlaystate)->tid();
	} else {
		SONOS_Log undef, 2, "ConsumMessage: Sorry. I don't understand you - '$msg'.";
		send($client, "Sorry. I don't understand you - '$msg'.\r\n", 0);
	}
}

########################################################################################
# SONOS_Client_IsAlive: Checks of the clients are already available
########################################################################################
sub SONOS_Client_IsAlive() {
	my $interval = SONOS_Max(10, SONOS_Client_Data_Retreive('undef', 'def', 'INTERVAL', 0));
	my $stepInterval = 0.5;
	
	SONOS_Log undef, 1, 'IsAlive-Thread gestartet. Warte 120 Sekunden und pruefe dann alle '.$interval.' Sekunden...';
	
	my $runEndlessLoop = 1;
	
	$SIG{'PIPE'} = 'IGNORE';
	$SIG{'CHLD'} = 'IGNORE';
	
	$SIG{'INT'} = sub {
		$runEndlessLoop = 0;
	};
	
	# Erst nach einer Weile wartens anfangen zu arbeiten. Bis dahin sollten alle Player im Netz erkannt, und deren Konfigurationen bekannt sein.
	my $counter = 0;
	do {
		select(undef, undef, undef, 0.5);
	} while (($counter++ < 240) && $runEndlessLoop);
	
	my $stepCounter = 0;
	while($runEndlessLoop) {
		select(undef, undef, undef, $stepInterval);
		
		next if (($stepCounter += $stepInterval) < $interval);
		$stepCounter = 0;
		
		# Alle bekannten Player durchgehen, wenn der Thread nicht beendet werden soll
		if ($runEndlessLoop) {
			my @list = @{$SONOS_Client_Data{PlayerAlive}};
			my @toAnnounce = ();
			for(my $i = 0; $i <= $#list; $i++) {
				next if (!$list[$i]);
				
				if (!SONOS_IsAlive($list[$i])) {
					# Auf die Entfernen-Meldeliste setzen
					push @toAnnounce, $list[$i];
					
					# Wenn er nicht mehr am Leben ist, dann auch aus der Aktiven-Liste entfernen
					delete @{$SONOS_Client_Data{PlayerAlive}}[$i];
				}
			}
			
			# Wenn ein Player gerade verschwunden ist, dann dem (verbleibenden) Sonos-System das mitteilen
			foreach my $toDeleteElem (@toAnnounce) {
				if ($toDeleteElem =~ m/(^.*)_/) {
					$toDeleteElem = $1;
					SONOS_Log undef, 3, 'ReportUnresponsiveDevice: '.$toDeleteElem;
					foreach my $udn (@{$SONOS_Client_Data{PlayerAlive}}) {
						next if (!$udn);
						
						my %data;
						$data{WorkType} = 'reportUnresponsiveDevice';
						$data{UDN} = $udn;
						my @params = ();
						push @params, $toDeleteElem;
						$data{Params} = \@params;
						
						$SONOS_ComObjectTransportQueue->enqueue(\%data);
						
						# Signalhandler aufrufen, wenn er nicht sowieso noch läuft...
						threads->object($SONOS_Thread)->kill('HUP') if ($SONOS_ComObjectTransportQueue->pending() == 1);
						
						# Da ich das nur an den ersten verfügbaren Player senden muss, kann hier die Schleife direkt beendet werden
						last;
					}
				}
			}
		}
	}
	
	SONOS_Log undef, 1, 'IsAlive-Thread wurde beendet.';
	$SONOS_Thread_IsAlive = -1;
}
########################################################################################
########################################################################################
##
##  End of Telnet-Server-Part for Sonos UPnP-Messages
##
########################################################################################
########################################################################################


=pod
=begin html

<a name="SONOS"></a>
<h3>SONOS</h3>
<p>FHEM-Module to communicate with the Sonos-System via UPnP</p>
<p>For more informations have also a closer look at the wiki at <a href="http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel">http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel</a></p>
<p>For correct functioning of this module it is neccessary to have some Perl-Modules installed, which has eventually installed manually:<ul>
<li><code>LWP::Simple</code></li>
<li><code>LWP::UserAgent</code></li>
<li><code>SOAP::Lite</code></li>
<li><code>HTTP::Request</code></li></ul></p>
<p><b>Attention!</b><br />This Module will not be functioning on any platform, because of the use of Threads and the neccessary Perl-modules.</p>
<p>More information is given in a (german) Wiki-article: <a href="http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel">http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel</a></p>
<p>The system conists of two different components:<br />
1. A UPnP-Client which runs as a standalone process in the background and takes the communications to the sonos-components.<br />
2. The FHEM-module itself which connects to the UPnP-client to make fhem able to work with sonos.<br /><br />
The client will be startet by the module itself if not done in another way.<br />
You can start this client on your own (to let it run instantly and independent from FHEM):<br />
<code>perl 00_SONOS.pm 4711</code>: Starts a UPnP-Client in an independant way who listens to connections on port 4711. This process can run a long time, FHEM can connect and disconnect to it.</p>
<h4>Example</h4>
<p>
<code>define Sonos SONOS localhost:4711 30</code>
</p>
<br />
<a name="SONOSdefine"></a>
<h4>Define</h4>
<code>define &lt;name&gt; SONOS [upnplistener] [[[interval] waittime] delaytime]</code>
        <br /><br /> Define a Sonos interface to communicate with a Sonos-System.<br />
<p>
<code>[upnplistener]</code><br />The name and port of the external upnp-listener. If not given, defaults to <code>localhost:4711</code>. The port has to be a free portnumber on your system. If you don't start a server on your own, the script does itself.<br />If you start it yourself write down the correct informations to connect.</p>
<p>
<code>[interval]</code><br /> The interval is for alive-checking of Zoneplayer-device, because no message come if the host disappear :-)<br />If omitted a value of 10 seconds is the default.</p>
<p>
<code>[waittime]</code><br /> With this value you can configure the waiting time for the starting of the Subprocess.</p>
<p>
<code>[delaytime]</code><br /> With this value you can configure a delay time before starting the network-part.</p>
<br />
<br />
<a name="SONOSset"></a>
<h4>Set</h4>
<ul>
<li><b>Control-Commands</b><ul>
<li><a name="SONOS_setter_PauseAll">
<code>set &lt;name&gt; PauseAll</code></a>
<br />Pause all Zoneplayer.</li>
<li><a name="SONOS_setter_StopAll">
<code>set &lt;name&gt; StopAll</code></a>
<br />Stops all Zoneplayer.</li>
</ul></li>
<li><b>Group-Commands</b><ul>
<li><a name="SONOS_setter_Groups">
<code>set &lt;name&gt; Groups &lt;GroupDefinition&gt;</code></a>
<br />Sets the current groups on the whole Sonos-System. The format is the same as retreived by getter 'Groups'.</li>
</ul></li>
</ul>
<br />
<a name="SONOSget"></a> 
<h4>Get</h4>
<ul>
<li><b>Group-Commands</b><ul>
<li><a name="SONOS_getter_Groups">
<code>get &lt;name&gt; Groups</code></a>
<br />Retreives the current group-configuration of the Sonos-System. The format is a comma-separated List of Lists with devicenames e.g. <code>[Sonos_Kueche], [Sonos_Wohnzimmer, Sonos_Schlafzimmer]</code>. In this example there are two groups: the first consists of one player and the second consists of two players.<br />
The order in the sublists are important, because the first entry defines the so-called group-coordinator (in this case <code>Sonos_Wohnzimmer</code>), from which the current playlist and the current title playing transferred to the other member(s).</li>
</ul></li>
</ul>
<br />
<a name="SONOSattr"></a>
<h4>Attributes</h4>
<ul>
<li><b>Common</b><ul>
<li><a name="SONOS_attribut_characterDecoding"><code>attr &lt;name&gt; characterDecoding &lt;codingname&gt;</code>
</a><br />With this attribute you can define a character-decoding-class. E.g. &lt;UTF-8&gt;. Default is &lt;CP-1252&gt;.</li>
<li><a name="SONOS_attribut_pingType"><code>attr &lt;name&gt; pingType &lt;string&gt;</code>
</a><br /> One of (none,tcp,udp,icmp,syn). Defines which pingType for alive-Checking has to be used. If set to 'none' no checks will be done.</li>
</ul></li>
<li><b>Proxy Configuration</b><ul>
<li><a name="SONOS_attribut_generateProxyAlbumArtURLs"><code>attr &lt;name&gt; generateProxyAlbumArtURLs &lt;int&gt;</code>
</a><br />One of (0, 1). If defined, all Cover-Links (the readings "currentAlbumArtURL" and "nextAlbumArtURL") are generated as links to the internal Sonos-Module-Proxy. It can be useful if you access Fhem over an external proxy and therefore have no access to the local network (the URLs are direct URLs to the Sonosplayer instead).</li>
<li><a name="SONOS_attribut_proxyCacheDir"><code>attr &lt;name&gt; proxyCacheDir &lt;Path&gt;</code>
</a><br />Defines a directory where the cached Coverfiles can be placed. If not defined "/tmp" will be used.</li>
<li><a name="SONOS_attribut_proxyCacheTime"><code>attr &lt;name&gt; proxyCacheTime &lt;int&gt;</code>
</a><br />A time in seconds. With a definition other than "0" the caching mechanism of the internal Sonos-Module-Proxy will be activated. If the filetime of the chached cover is older than this time, it will be reloaded from the Sonosplayer.</li>
</ul></li>
<li><b>Speak Configuration</b><ul>
<li><a name="SONOS_attribut_targetSpeakDir"><code>attr &lt;name&gt; targetSpeakDir &lt;string&gt;</code>
</a><br /> Defines, which Directory has to be used for the Speakfiles</li>
<li><a name="SONOS_attribut_targetSpeakURL"><code>attr &lt;name&gt; targetSpeakURL &lt;string&gt;</code>
</a><br /> Defines, which URL has to be used for accessing former stored Speakfiles as seen from the SonosPlayer</li>
<li><a name="SONOS_attribut_targetSpeakFileTimestamp"><code>attr &lt;name&gt; targetSpeakFileTimestamp &lt;int&gt;</code>
</a><br /> One of (0, 1). Defines, if the Speakfile should have a timestamp in his name. That makes it possible to store all historical Speakfiles.</li>
<li><a name="SONOS_attribut_targetSpeakFileHashCache"><code>attr &lt;name&gt; targetSpeakFileHashCache &lt;int&gt;</code>
</a><br /> One of (0, 1). Defines, if the Speakfile should have a hash-value in his name. If this value is set to one an already generated file with the same hash is re-used and not newly generated.</li>
<li><a name="SONOS_attribut_Speak1"><code>attr &lt;name&gt; Speak1 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />Defines a systemcall commandline for generating a speaking file out of the given text. If such an attribute is defined, an associated setter at the Sonosplayer-Device is available. The following placeholders are available:<br />'''%language%''': Will be replaced by the given language-parameter<br />'''%filename%''': Will be replaced by the complete target-filename (incl. fileextension).<br />'''%text%''': Will be replaced with the given text</li>
<li><a name="SONOS_attribut_Speak2"><code>attr &lt;name&gt; Speak2 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />See Speak1</li>
<li><a name="SONOS_attribut_Speak3"><code>attr &lt;name&gt; Speak3 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />See Speak1</li>
<li><a name="SONOS_attribut_Speak4"><code>attr &lt;name&gt; Speak4 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />See Speak1</li>
<li><a name="SONOS_attribut_SpeakCover"><code>attr &lt;name&gt; SpeakCover &lt;Filename&gt;</code>
</a><br />Defines a Cover for use by the speak generation process. If not defined the Fhem-logo will be used.</li>
<li><a name="SONOS_attribut_Speak1Cover"><code>attr &lt;name&gt; Speak1Cover &lt;Filename&gt;</code>
</a><br />See SpeakCover</li>
<li><a name="SONOS_attribut_Speak2Cover"><code>attr &lt;name&gt; Speak2Cover &lt;Filename&gt;</code>
</a><br />See SpeakCover</li>
<li><a name="SONOS_attribut_Speak3Cover"><code>attr &lt;name&gt; Speak3Cover &lt;Filename&gt;</code>
</a><br />See SpeakCover</li>
<li><a name="SONOS_attribut_Speak4Cover"><code>attr &lt;name&gt; Speak4Cover &lt;Filename&gt;</code>
</a><br />See SpeakCover</li>
</ul></li>
</ul>

=end html

=begin html_DE

<a name="SONOS"></a>
<h3>SONOS</h3>
<p>FHEM-Modul für die Anbindung des Sonos-Systems via UPnP</p>
<p>Für weitere Hinweise und Beschreibungen bitte auch im Wiki unter <a href="http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel">http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel</a> nachschauen.</p>
<p>Für die Verwendung sind Perlmodule notwendig, die unter Umständen noch nachinstalliert werden müssen:<ul>
<li><code>LWP::Simple</code></li>
<li><code>LWP::UserAgent</code></li>
<li><code>SOAP::Lite</code></li>
<li><code>HTTP::Request</code></li></ul></p>
<p><b>Achtung!</b><br />Das Modul wird nicht auf jeder Plattform lauffähig sein, da Threads und die angegebenen Perl-Module verwendet werden.</p>
<p>Mehr Informationen im (deutschen) Wiki-Artikel: <a href="http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel">http://www.fhemwiki.de/wiki/Sonos_Anwendungsbeispiel</a></p>
<p>Das System besteht aus zwei Komponenten:<br />
1. Einem UPnP-Client, der als eigener Prozess im Hintergrund ständig läuft, und die Kommunikation mit den Sonos-Geräten übernimmt.<br />
2. Dem eigentlichen FHEM-Modul, welches mit dem UPnP-Client zusammenarbeitet, um die Funktionalität in FHEM zu ermöglichen.<br /><br />
Der Client wird im Notfall automatisch von Modul selbst gestartet.<br />
Man kann den Server unabhängig von FHEM selbst starten (um ihn dauerhaft und unabh&auml;ngig von FHEM laufen zu lassen):<br />
<code>perl 00_SONOS.pm 4711</code>: Startet einen unabhängigen Server, der auf Port 4711 auf eingehende FHEM-Verbindungen lauscht. Dieser Prozess kann dauerhaft laufen, FHEM kann sich verbinden und auch wieder trennen.</p>
<h4>Beispiel</h4>
<p>
<code>define Sonos SONOS localhost:4711 30</code>
</p>
<br />
<a name="SONOSdefine"></a>
<h4>Definition</h4>
<code>define &lt;name&gt; SONOS [upnplistener] [[[interval] waittime] delaytime]</code>
        <br /><br /> Definiert das Sonos interface für die Kommunikation mit dem Sonos-System.<br />
<p>
<code>[upnplistener]</code><br />Name und Port eines externen UPnP-Client. Wenn nicht angegebenen wird <code>localhost:4711</code> festgelegt. Der Port muss eine freie Portnummer ihres Systems sein. <br />Wenn sie keinen externen Client gestartet haben, startet das Skript einen eigenen.<br />Wenn sie einen eigenen Dienst gestartet haben, dann geben sie hier die entsprechenden Informationen an.</p>
<p>
<code>[interval]</code><br /> Das Interval wird für die Überprüfung eines Zoneplayers benötigt. In diesem Interval wird nachgeschaut, ob der Player noch erreichbar ist, da sich ein Player nicht mehr abmeldet, wenn er abgeschaltet wird :-)<br />Wenn nicht angegeben, wird ein Wert von 10 Sekunden angenommen.</p>
<p>
<code>[waittime]</code><br /> Hiermit wird die Wartezeit eingestellt, die nach dem Starten des SubProzesses darauf gewartet wird.</p>
<p>
<code>[delaytime]</code><br /> Hiermit kann eine Verzögerung eingestellt werden, die vor dem Starten des Netzwerks gewartet wird.</p>
<br />
<br />
<a name="SONOSset"></a>
<h4>Set</h4>
<ul>
<li><b>Steuerbefehle</b><ul>
<li><a name="SONOS_setter_PauseAll">
<code>set &lt;name&gt; PauseAll</code></a>
<br />Pausiert die Wiedergabe in allen Zonen.</li>
<li><a name="SONOS_setter_StopAll">
<code>set &lt;name&gt; StopAll</code></a>
<br />Stoppt die Wiedergabe in allen Zonen.</li>
</ul></li>
<li><b>Gruppenbefehle</b><ul>
<li><a name="SONOS_setter_Groups">
<code>set &lt;name&gt; Groups &lt;GroupDefinition&gt;</code></a>
<br />Setzt die aktuelle Gruppierungskonfiguration der Sonos-Systemlandschaft. Das Format ist jenes, welches auch von dem Get-Befehl 'Groups' geliefert wird.</li>
</ul></li>
</ul>
<br />
<a name="SONOSget"></a> 
<h4>Get</h4>
<ul>
<li><b>Gruppenbefehle</b><ul>
<li><a name="SONOS_getter_Groups">
<code>get &lt;name&gt; Groups</code></a>
<br />Liefert die aktuelle Gruppierungskonfiguration der Sonos Systemlandschaft zurück. Das Format ist eine Kommagetrennte Liste von Listen mit Devicenamen, also z.B. <code>[Sonos_Kueche], [Sonos_Wohnzimmer, Sonos_Schlafzimmer]</code>. In diesem Beispiel sind also zwei Gruppen definiert, von denen die erste aus einem Player und die zweite aus Zwei Playern besteht.<br />
Dabei ist die Reihenfolge innerhalb der Unterlisten wichtig, da der erste Eintrag der sogenannte Gruppenkoordinator ist (in diesem Fall also <code>Sonos_Wohnzimmer</code>), von dem die aktuelle Abspielliste un der aktuelle Titel auf die anderen Gruppenmitglieder übernommen wird.</li>
</ul></li>
</ul>
<br />
<a name="SONOSattr"></a>
<h4>Attribute</h4>
<ul>
<li><b>Grundsätzliches</b><ul>
<li><a name="SONOS_attribut_characterDecoding"><code>attr &lt;name&gt; characterDecoding &lt;codingname&gt;</code>
</a><br />Hiermit kann die Zeichendekodierung eingestellt werden. Z.b. &lt;UTF-8&gt;. Standardm&auml;&szlig;ig wird &lt;CP-1252&gt; verwendet.</li>
<li><a name="SONOS_attribut_pingType"><code>attr &lt;name&gt; pingType &lt;string&gt;</code>
</a><br /> One of (none,tcp,udp,icmp,syn). Gibt an, welche Methode für die Ping-Überprüfung verwendet werden soll. Wenn 'none' angegeben wird, dann wird keine Überprüfung gestartet.</li>
</ul></li>
<li><b>Proxy-Einstellungen</b><ul>
<li><a name="SONOS_attribut_generateProxyAlbumArtURLs"><code>attr &lt;name&gt; generateProxyAlbumArtURLs &lt;int&gt;</code>
</a><br /> Aus (0, 1). Wenn aktiviert, werden alle Cober-Links als Proxy-Aufrufe an Fhem generiert. Dieser Proxy-Server wird vom Sonos-Modul bereitgestellt. In der Grundeinstellung erfolgt kein Caching der Cover, sondern nur eine Durchreichung der Cover von den Sonosplayern (Damit ist der Zugriff durch einen externen Proxyserver auf Fhem möglich).</li>
<li><a name="SONOS_attribut_proxyCacheDir"><code>attr &lt;name&gt; proxyCacheDir &lt;Path&gt;</code>
</a><br /> Hiermit wird das Verzeichnis festgelegt, in dem die Cober zwischengespeichert werden. Wenn nicht festegelegt, so wird "/tmp" verwendet.</li>
<li><a name="SONOS_attribut_proxyCacheTime"><code>attr &lt;name&gt; proxyCacheTime &lt;int&gt;</code>
</a><br /> Mit einer Angabe ungleich 0 wird der Caching-Mechanismus des Sonos-Modul-Proxy-Servers aktiviert. Dabei werden Cover, die im Cache älter sind als diese Zeitangabe in Sekunden, neu vom Sonosplayer geladen, alle anderen direkt ausgeliefert, ohne den Player zu fragen.</li>
</ul></li>
<li><b>Sprachoptionen</b><ul>
<li><a name="SONOS_attribut_targetSpeakDir"><code>attr &lt;name&gt; targetSpeakDir &lt;string&gt;</code>
</a><br /> Gibt an, welches Verzeichnis für die Ablage des MP3-Files der Textausgabe verwendet werden soll</li>
<li><a name="SONOS_attribut_targetSpeakURL"><code>attr &lt;name&gt; targetSpeakURL &lt;string&gt;</code>
</a><br /> Gibt an, unter welcher Adresse der ZonePlayer das unter targetSpeakDir angegebene Verzeichnis erreichen kann.</li>
<li><a name="SONOS_attribut_targetSpeakFileTimestamp"><code>attr &lt;name&gt; targetSpeakFileTimestamp &lt;int&gt;</code>
</a><br /> One of (0, 1). Gibt an, ob die erzeugte MP3-Sprachausgabedatei einen Zeitstempel erhalten soll (1) oder nicht (0).</li>
<li><a name="SONOS_attribut_targetSpeakFileHashCache"><code>attr &lt;name&gt; targetSpeakFileHashCache &lt;int&gt;</code>
</a><br /> One of (0, 1). Gibt an, ob die erzeugte Sprachausgabedatei einen Hashwert erhalten soll (1) oder nicht (0). Wenn dieser Wert gesetzt wird, dann wird eine bereits bestehende Datei wiederverwendet, und nicht neu erzeugt.</li>
<li><a name="SONOS_attribut_Speak1"><code>attr &lt;name&gt; Speak1 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />Hiermit kann ein Systemaufruf definiert werden, der zu Erzeugung einer Sprachausgabe verwendet werden kann. Sobald dieses Attribut definiert wurde, ist ein entsprechender Setter am Sonosplayer verfügbar.<br />Es dürfen folgende Platzhalter verwendet werden:<br />'''%language%''': Wird durch die eingegebene Sprache ersetzt<br />'''%filename%''': Wird durch den kompletten Dateinamen (inkl. Dateiendung) ersetzt.<br />'''%text%''': Wird durch den zu übersetzenden Text ersetzt.</li>
<li><a name="SONOS_attribut_Speak2"><code>attr &lt;name&gt; Speak2 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />Siehe Speak1</li>
<li><a name="SONOS_attribut_Speak3"><code>attr &lt;name&gt; Speak3 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />Siehe Speak1</li>
<li><a name="SONOS_attribut_Speak4"><code>attr &lt;name&gt; Speak4 &lt;Fileextension&gt;:&lt;Commandline&gt;</code>
</a><br />Siehe Speak1</li>
<li><a name="SONOS_attribut_SpeakCover"><code>attr &lt;name&gt; SpeakCover &lt;Absolute-Imagepath&gt;</code>
</a><br />Hiermit kann ein JPG- oder PNG-Bild als Cover für die Sprachdurchsagen definiert werden.</li>
<li><a name="SONOS_attribut_Speak1Cover"><code>attr &lt;name&gt; Speak1Cover &lt;Absolute-Imagepath&gt;</code>
</a><br />Analog zu SpeakCover für Speak1.</li>
<li><a name="SONOS_attribut_Speak2Cover"><code>attr &lt;name&gt; Speak2Cover &lt;Absolute-Imagepath&gt;</code>
</a><br />Analog zu SpeakCover für Speak2.</li>
<li><a name="SONOS_attribut_Speak3Cover"><code>attr &lt;name&gt; Speak3Cover &lt;Absolute-Imagepath&gt;</code>
</a><br />Analog zu SpeakCover für Speak3.</li>
<li><a name="SONOS_attribut_Speak3Cover"><code>attr &lt;name&gt; Speak3Cover &lt;Absolute-Imagepath&gt;</code>
</a><br />Analog zu SpeakCover für Speak3.</li>
<li><a name="SONOS_attribut_Speak4Cover"><code>attr &lt;name&gt; Speak4Cover &lt;Absolute-Imagepath&gt;</code>
</a><br />Analog zu SpeakCover für Speak4.</li>
</ul></li>
</ul>

=end html_DE
=cut