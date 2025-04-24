<?php

//  Set Up
include 'secrets.php';
$dsn = "mysql:host=courses;dbname=" . $username;
$link = "http://students.cs.niu.edu/~" . $username . "/KaraokeProject.php";


//  Preset MariaDB Database Commands
try
{
    $pdo = new PDO($dsn, $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    //  User
    $SU = $pdo->prepare("SELECT User.Name AS Username, User.AccountBalance AS 'Account Balance', User.UserID AS uID FROM User;");
    if(!$SU) { echo "Error preparing Show Users"; die(); }
    
    $GUA = $pdo->prepare("SELECT User.AccountBalance AS 'Account Balance' FROM User WHERE User.UserID = :uID;");
    if(!$GUA) { echo "Error preparing Get User Account"; die(); }

    $UUA = $pdo->prepare("UPDATE User SET User.AccountBalance = User.AccountBalance - :a WHERE User.UserID = :uID;");
    if(!$UUA) { echo "Error preparing Update User Account"; die(); }
    
    //  DJ
    $SD = $pdo->prepare("SELECT DJ.Name AS Name, DJ.DJID AS dID FROM DJ;");
    if(!$SD) { echo "Error preparing Show DJs"; die(); }
    
    //  Song List
    $SL = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.ArtistID = Artist.ArtistID;");
    if(!$SL) { echo "Error preparing Song List"; die(); }
    $SLTA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.ArtistID = Artist.ArtistID ORDER BY Song.Name ASC, Artist.Name ASC;");
    if(!$SLTA) { echo "Error preparing Song List by Title Ascending"; die(); }
    $SLTD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.ArtistID = Artist.ArtistID ORDER BY Song.Name DESC, Artist.Name DESC;");
    if(!$SLTD) { echo "Error preparing Song List by Title Descending"; die(); }
    $SLAA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name ASC, Song.Name ASC;");
    if(!$SLAA) { echo "Error preparing Song List by Artist Ascending"; die(); }
    $SLAD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name DESC, Song.Name DESC;");
    if(!$SLAD) { echo "Error preparing Song List by Artist Descending"; die(); }
    
    //  Version List
    $VL = $pdo->prepare("SELECT Version.Name AS Version, VersionID AS vID FROM Version WHERE Version.SongID = :sID;");
    if(!$VL) { echo "Error preparing Version List"; die(); }

    //  Artist Searches
    $SA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Artist.Name = :a AND Song.ArtistID = Artist.ArtistID;");
    if(!$SA) { echo "Error preparing Search Artist"; die(); }
    $SATA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Artist.Name = :a AND Song.ArtistID = Artist.ArtistID ORDER BY Song.Name ASC, Artist.Name ASC;");
    if(!$SATA) { echo "Error preparing Sort Artist by Title Ascending"; die(); }
    $SATD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Artist.Name = :a AND Song.ArtistID = Artist.ArtistID ORDER BY Song.Name DESC, Artist.Name DESC;");
    if(!$SATD) { echo "Error preparing Sort Artist by Title Descending"; die(); }
    $SAAA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Artist.Name = :a AND Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name ASC, Song.Name ASC;");
    if(!$SAAA) { echo "Error preparing Sort Artist by Artist Ascending"; die(); }
    $SAAD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Artist.Name = :a AND Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name DESC, Song.Name DESC;");
    if(!$SAAD) { echo "Error preparing Sort Artist by Artist Descending"; die(); }

    //  Title Searches
    $ST = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Song.SongID AS sID FROM Song, Artist WHERE Song.Name = :t AND Song.ArtistID = Artist.ArtistID;");
    if(!$ST) { echo "Error preparing Search Title"; die(); }
    $STTA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist Song.SongID AS sID FROM Song, Artist WHERE Song.Name = :t AND Song.ArtistID = Artist.ArtistID ORDER BY Song.Name ASC, Artist.Name ASC;");
    if(!$STTA) { echo "Error preparing Sort Title by Title Ascending"; die(); }
    $STTD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist Song.SongID AS sID FROM Song, Artist WHERE Song.Name = :t AND Song.ArtistID = Artist.ArtistID ORDER BY Song.Name DESC, Artist.Name DESC;");
    if(!$STTD) { echo "Error preparing Sort Title by Title Descending"; die(); }
    $STAA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist Song.SongID AS sID FROM Song, Artist WHERE Song.Name = :t AND Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name ASC, Song.Name ASC;");
    if(!$STAA) { echo "Error preparing Sort Title by Artist Ascending"; die(); }
    $STAD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist Song.SongID AS sID FROM Song, Artist WHERE Song.Name = :t AND Song.ArtistID = Artist.ArtistID ORDER BY Artist.Name DESC, Song.Name DESC;");
    if(!$STAD) { echo "Error preparing Sort Title by Artist Descending"; die(); }

    //  Contributor Searches
    $SC = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID;");
    if(!$SC) { echo "Error preparing Search Contributor"; die(); }
    $SCTA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Song.Name ASC, Artist.Name ASC, Contributor.Name ASC;");
    if(!$SCTA) { echo "Error preparing Sort Contributor by Title Ascending"; die(); }
    $SCTD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Song.Name DESC, Artist.Name DESC, Contributor.Name DESC;");
    if(!$SCTD) { echo "Error preparing Sort Contributor by Title Descending"; die(); }
    $SCAA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Artist.Name ASC, Song.Name ASC, Contributor.Name ASC;");
    if(!$SCAA) { echo "Error preparing Sort Contributor by Artist Ascending"; die(); }
    $SCAD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Artist.Name DESC, Song.Name DESC, Contributor.Name DESC;");
    if(!$SCAD) { echo "Error preparing Sort Contributor by Artist Descending"; die(); }
    $SCCA = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Contributor.Name ASC, Song.Name ASC, Artist.Name ASC;");
    if(!$SCCA) { echo "Error preparing Sort Contributor by Contributor Ascending"; die(); }
    $SCCD = $pdo->prepare("SELECT Song.Name AS Title, Artist.Name AS Artist, Producer.Contribution AS Contribution, Song.SongID AS sID FROM Song, Artist, Contributor, Producer WHERE Contributor.Name = :c AND Contributor.ContributorID = Producer. ContributorID AND Producer.SongID = Song.SongID AND Artist.ArtistID = Song.ArtistID ORDER BY Contributor.Name DESC, Song.Name DESC, Artist.Name DESC;");
    if(!$SCCD) { echo "Error preparing Sort Contributor by Contributor Descending"; die(); }
    
    //	Free Queue
    $FQ = $pdo->prepare("SELECT User.Name AS Username, Song.Name AS Title, Version.Name AS Version, Artist.Name AS Artist, Version.VersionID AS 'File ID', FreeQueue.DateTime AS 'Date Time', FreeQueueID AS fqID FROM User, Song, Artist, Version, FreeQueue WHERE FreeQueue.UserID = User.UserID AND FreeQueue.VersionID = Version.VersionID AND Version.SongID = Song.SongID AND Song.ArtistID = Artist.ArtistID ORDER BY FreeQueue.DateTime ASC;");
    if(!$FQ) { echo "Error preparing Free Queue"; die(); }
    
    $GFQ = $pdo->prepare("SELECT User.Name AS Username, Song.Name AS Title, Artist.Name AS Artist, Version.Name AS Version FROM User, Song, Artist, Version, FreeQueue WHERE FreeQueue.FreeQueueID = :fqID;");
    if(!$GFQ) { echo "Error preparing Get User Account"; die(); }

    $IFQ = $pdo->prepare("INSERT INTO FreeQueue(UserID, VersionID) VALUES (:uID, :vID);");
    if(!$IFQ) { echo "Error preparing Insert Free Queue"; die(); }

    $DFQ = $pdo->prepare("DELETE FROM FreeQueue WHERE FreeQueueID = :fqID;");
    if(!$DFQ) { echo "Error preparing Delete from Free Queue"; die(); }

    //	Paid Queue
    $PQ = $pdo->prepare("SELECT User.Name AS Username, Song.Name AS Title, Version.Name AS Version, Artist.Name AS Artist, Version.VersionID AS 'File ID', PaidQueue.DateTime AS 'Date Time', PaidQueue.AmountPaid AS 'Amount Paid', PaidQueueID AS pqID FROM User, Song, Artist, Version, PaidQueue WHERE PaidQueue.UserID = User.UserID AND PaidQueue.VersionID = Version.VersionID AND Version.SongID = Song.SongID AND Song.ArtistID = Artist.ArtistID ORDER BY PaidQueue.DateTime ASC, PaidQueue.AmountPaid DESC;");
    if(!$PQ) { echo "Error preparing Paid Queue"; die(); }
    $PQS = $pdo->prepare("SELECT User.Name AS Username, Song.Name AS Title, Version.Name AS Version, Artist.Name AS Artist, Version.VersionID AS 'File ID', PaidQueue.DateTime AS 'Date Time', PaidQueue.AmountPaid AS 'Amount Paid', PaidQueueID AS pqID FROM User, Song, Artist, Version, PaidQueue WHERE PaidQueue.UserID = User.UserID AND PaidQueue.VersionID = Version.VersionID AND Version.SongID = Song.SongID AND Song.ArtistID = Artist.ArtistID ORDER BY PaidQueue.AmountPaid DESC, PaidQueue.DateTime ASC;");
    if(!$PQS) { echo "Error preparing Paid Queue Sorted"; die(); }

    $GPQ = $pdo->prepare("SELECT User.Name AS Username, Song.Name AS Title, Artist.Name AS Artist, Version.Name AS Version, PaidQueue.AmountPaid AS Amount FROM User, Song, Artist, Version, PaidQueue WHERE PaidQueue.PaidQueueID = :pqID;");
    if(!$GPQ) { echo "Error preparing Get User Account"; die(); }

    $IPQ = $pdo->prepare("INSERT INTO PaidQueue(UserID, VersionID, AmountPaid) VALUES (:uID, :vID, :a);");
    if(!$IPQ) { echo "Error preparing Insert Paid Queue"; die(); }

    $DPQ = $pdo->prepare("DELETE FROM PaidQueue WHERE PaidQueueID = :pqID;");
    if(!$DPQ) { echo "Error preparing Delete from Paid Queue"; die(); }
}
catch(PDOexception $e)
{
    echo "Connection to database failed: " . $e->getMessage(); die();
}

//	Table Functions
function draw_table($rows)
{
  if(empty($rows)) { echo "<p>No results found.</p>"; }
  else
  {
    echo "<table border=1>";

    echo "<tr>";
    foreach($rows[0] as $key => $item)
    {
      echo "<th>$key</th>";
    }
    echo "</tr>";

    foreach($rows as $row)
    {
      echo "<tr>";
      foreach($row as $item)
      {
        echo "<td>$item</td>";
      }
      echo "</tr>";
    }
    echo "</table>";
  }
}

function draw_table_ignore($rows, $ignoreVar)
{
    if(empty($rows)) { echo "<p>No results found.</p>"; }
    else
    {
        echo "<table border=1>";

        echo "<tr>";
        foreach($rows[0] as $key => $item)
        {
            if ($key != $ignoreVar)
                echo "<th>$key</th>";
        }
        echo "</tr>";

        foreach($rows as $row)
        {
            echo "<tr>";
            foreach($row as $key => $item)
            {
                if ($key != $ignoreVar)
                    echo "<td>$item</td>";
            }
            echo "</tr>";
        }
        echo "</table>";
    }
}

function draw_table_buttons($rows, $link, $buttonVar, $buttonName)
{
    if(empty($rows)) { echo "<p>No results found.</p>"; }
    else	
    {
        echo "<form action=\"" . $link . "\" method=\"Post\"><table border=1><tr>";

        foreach($rows[0] as $key => $item)
        {
            if ($key != $buttonVar)
                echo "<th>$key</th>";
        }

        echo "<th>Action</th></tr>";

        foreach($rows as $row)
        {
            echo "<tr>";
            foreach($row as $key => $item)
            {
                if ($key != $buttonVar)
                    echo "<td>$item</td>";
            }
            
            echo "<td>";
            echo	 "<button type=\"submit\" name=\"" . $buttonVar . "\" value=\"" . $row[$buttonVar] . "\">" . $buttonName . "</button>";
            echo "</td></tr>";
        }
        echo "</table></form>";
    }
}

function draw_sort_table_buttons($rows, $buttonVar, $buttonName, $sortHeader)
{
    if(empty($rows)) { echo "<p>No results found.</p>"; }
    else	
    {
        echo "<table border=1><tr>";

        foreach($rows[0] as $key => $item)
        {
            if ($key != $buttonVar)
            {
                echo "<th>$key";
                echo "<br/>";
                echo "<button type=\"submit\" name=\"Sort\" value=\"" . $sortHeader[$key][0] . "\">Ascending</button>";
                echo "<button type=\"submit\" name=\"Sort\" value=\"" . $sortHeader[$key][1] . "\">Descending</button>";
                echo "</th>";
            }
        }
        echo "<th>Action</th></tr>";

        foreach($rows as $row)
        {
            echo "<tr>";
            foreach($row as $key => $item)
            {
                if ($key != $buttonVar)
                    echo "<td>$item</td>";
            }
            
            echo "<td>";
            echo	 "<button type=\"submit\" name=\"" . $buttonVar . "\" value=\"" . $row[$buttonVar] . "\">" . $buttonName . "</button>";
            echo "</td></tr>";
        }
        echo "</table>";
    }
}

function draw_paid_queue_table($rows, $link)
{
    if(empty($rows)) { echo "<p>No results found.</p>"; }
    else	
    {
        echo "<form action=\"" . $link . "\" method=\"Post\"><table border=1>";
        echo '<button type="submit" name="" value="">Sort by Time</button>';
        echo '<button type="submit" name="Sort" value="">Sort by Amount Paid</button>';
        echo "<tr>";

        foreach($rows[0] as $key => $item)
        {
            if ($key != "pqID")
                echo "<th>$key</th>";
        }

        echo "<th>Action</th></tr>";

        foreach($rows as $row)
        {
            echo "<tr>";
            foreach($row as $key => $item)
            {
                if ($key != "pqID")
                    echo "<td>$item</td>";
            }
            
            echo "<td>";
            echo	 "<button type=\"submit\" name=\"pqID\" value=\"" . $row["pqID"] . "\">Select</button>";
            echo "</td></tr>";
        }
        echo "</table></form>";
    }
}

function Main_Menu($link)
{
    echo '<h2>Visit as a...</h2>';

    echo "<form action=\"" . $link . "\" method=\"Post\">";
    echo '<button type="submit" name="User" value="">User</button>';
    echo '<br/>';
    echo '<button type="submit" name="DJ" value="">DJ</button>';
    echo '</form>';
}


//  Main
?>

<html>
    <head>
        <title>Karaoke Project</title>
    </head>

    <body>
        <h1>Karaoke Project by Random F</h1>

        <?php
            if (isset($_POST["Reset"]))
            {
                Main_Menu($link);
            }
            elseif (isset($_POST["Queue"]))
            {
                if ($_POST["Queue"] == "Free")
                {
                    echo '<h2>You and your song have been added into the Free Queue</h2>';

                    $IFQ->execute(array(":uID" => $_POST["uID"], ":vID" => $_POST["vID"]));

                    $FQ->execute();
                    $rows = $FQ->fetchAll(PDO::FETCH_ASSOC);
                    draw_table_ignore($rows, "fqID");
                }
                else
                {
                    $GUA->execute(array(":uID" => $_POST["uID"]));
                    $account = $GUA->fetchColumn();

                    if (isset($_POST["Amount"]))
                    {
                        if ($_POST["Amount"] >= 0.01 and $_POST["Amount"] <= $account)
                        {
                            echo '<h2>You and your song have been added into the Paid Queue for $' . $_POST["Amount"] . '</h2>';

                            $IPQ->execute(array(":uID" => $_POST["uID"], ":vID" => $_POST["vID"], ":a" => $_POST["Amount"]));
                            $UUA->execute(array(":uID" => $_POST["uID"], ":a" => $_POST["Amount"]));
                        }
                        else
                        {
                            echo '<h2>Cannot spend that, input a valid amount (You have $' . $account . ')</h2>';
                            
                            echo "<form action=\"" . $link . "\" method=\"Post\">";
                            echo "<input type=\"hidden\" name=\"uID\" value=\"" . $_POST["uID"] .  "\">";
                            echo "<input type=\"hidden\" name=\"vID\" value=\"" . $_POST["vID"] .  "\">";
                            echo '<p>';
                            echo "<input type=\"text\" name=\"Amount\" value=\"" . ($_POST["Amount"]) .  "\">";
                            echo '<button type="submit" name="Queue" value="Pay">Confirm</button>';
                            echo '</p>';
                        }
                    }
                    else
                    {
                        echo '<h2>How much would you like to spend? (You have $' . $account . ')</h2>';

                        echo "<form action=\"" . $link . "\" method=\"Post\">";
                        echo "<input type=\"hidden\" name=\"uID\" value=\"" . $_POST["uID"] .  "\">";
                        echo "<input type=\"hidden\" name=\"vID\" value=\"" . $_POST["vID"] .  "\">";
                        echo '<p>';
                        echo '<input type="text" name="Amount" value="">';
                        echo '<button type="submit" name="Queue" value="Pay">Confirm</button>';
                        echo '</p>';
                    }

                    $PQ->execute();
                    $rows = $PQ->fetchAll(PDO::FETCH_ASSOC);
                    draw_table_ignore($rows, "pqID");
                }
            }
            elseif (isset($_POST["vID"]))
            {
                echo '<h2>Would you like to wait in a Free Queue or Paid Queue?</h2>';
                
                echo "<form action=\"" . $link . "\" method=\"Post\">";
                echo "<input type=\"hidden\" name=\"uID\" value=\"" . $_POST["uID"] .  "\">";
                echo "<input type=\"hidden\" name=\"vID\" value=\"" . $_POST["vID"] .  "\">";
                echo '<button type="submit" name="Queue" value="Paid">Paid Queue</button>';
                $PQ->execute();
                $rows = $PQ->fetchAll(PDO::FETCH_ASSOC);
                draw_table_ignore($rows, "pqID");
                echo '<br/>';
                echo '<button type="submit" name="Queue" value="Free">Free Queue</button>';
                $FQ->execute();
                $rows = $FQ->fetchAll(PDO::FETCH_ASSOC);
                draw_table_ignore($rows, "fqID");
                echo "</form>";
            }
            elseif (isset($_POST["sID"]))
            {
                echo '<h2>Select what version of the song you want</h2>';

                echo "<form action=\"" . $link . "\" method=\"Post\">";
                echo "<input type=\"hidden\" name=\"uID\" value=\"" . $_POST["uID"] .  "\">";
                echo "<input type=\"hidden\" name=\"sID\" value=\"" . $_POST["sID"] .  "\">";
                $VL->execute(array(":sID" => $_POST["sID"]));
                $rows = $VL->fetchAll(PDO::FETCH_ASSOC);
                draw_table_buttons($rows, $link, "vID", "Select");

                echo "</form>";
            }
            elseif (isset($_POST["uID"]))
            {
                echo '<h2>Search by Artist, Title, or Contributor.</h2>';

                echo "<form action=\"" . $link . "\" method=\"Post\">";
                echo "<input type=\"hidden\" name=\"uID\" value=\"" . $_POST["uID"] .  "\">";
                echo '<p>';

                if (isset($_POST["Input"]))
                    echo "<input type=\"text\" name=\"Input\" value=\"" . ($_POST["Input"]) .  "\">";
                else
                    echo '<input type="text" name="Input" value="">';

                echo '<button type="submit" name="Category" value="Artist">Artist</button>';
                echo '<button type="submit" name="Category" value="Title">Title</button>';
                echo '<button type="submit" name="Category" value="Contributor">Contributor</button>';
                echo '</p>';

                if (isset($_POST["Category"]))
                    echo "<input type=\"hidden\" name=\"Mem_Category\" value=\"" . $_POST["Category"] .  "\">";
                elseif (isset($_POST["Mem_Category"]))
                    echo "<input type=\"hidden\" name=\"Mem_Category\" value=\"" . $_POST["Mem_Category"] .  "\">";

                if (isset($_POST["Input"]) and (isset($_POST["Category"]) or isset($_POST["Mem_Category"])))
                {
                    if ($_POST["Input"] != "")
                    {
                        if ((isset($_POST["Category"]) and $_POST["Category"] == "Artist") or (!isset($_POST["Category"]) and $_POST["Mem_Category"] == "Artist"))
                        {
                            $sortHeader = array("Title" => array("TA","TD"), "Artist" => array("AA","AD"));
                            $rows;

                            if (isset($_POST["Sort"]))
                            {
                                if ($_POST["Sort"] == "TA")
                                {
                                    $SATA->execute(array(":a" => $_POST["Input"]));
                                    $rows = $SATA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "TD")
                                {
                                    $SATD->execute(array(":a" => $_POST["Input"]));
                                    $rows = $SATD->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AA")
                                {
                                    $SAAA->execute(array(":a" => $_POST["Input"]));
                                    $rows = $SAAA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AD")
                                {
                                    $SAAD->execute(array(":a" => $_POST["Input"]));
                                    $rows = $SAAD->fetchAll(PDO::FETCH_ASSOC);
                                }
                            }
                            else
                            {
                                $SA->execute(array(":a" => $_POST["Input"]));
                                $rows = $SA->fetchAll(PDO::FETCH_ASSOC);
                            }
                            
                            draw_sort_table_buttons($rows, "sID", "Select", $sortHeader);
                        }
                        elseif ((isset($_POST["Category"]) and $_POST["Category"] == "Title") or (!isset($_POST["Category"]) and $_POST["Mem_Category"] == "Title"))
                        {
                            $sortHeader = array("Title" => array("TA","TD"), "Artist" => array("AA","AD"));
                            $rows;

                            if (isset($_POST["Sort"]))
                            {
                                if ($_POST["Sort"] == "TA")
                                {
                                    $STTA->execute(array(":t" => $_POST["Input"]));
                                    $rows = $STTA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "TD")
                                {
                                    $STTD->execute(array(":t" => $_POST["Input"]));
                                    $rows = $STTD->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AA")
                                {
                                    $STAA->execute(array(":t" => $_POST["Input"]));
                                    $rows = $STAA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AD")
                                {
                                    $STAD->execute(array(":t" => $_POST["Input"]));
                                    $rows = $STAD->fetchAll(PDO::FETCH_ASSOC);
                                }
                            }
                            else
                            {
                                $ST->execute(array(":t" => $_POST["Input"]));
                                $rows = $ST->fetchAll(PDO::FETCH_ASSOC);
                            }
                                
                            draw_sort_table_buttons($rows, "sID", "Select", $sortHeader);
                        }
                        elseif ((isset($_POST["Category"]) and $_POST["Category"] == "Contributor") or (!isset($_POST["Category"]) and $_POST["Mem_Category"] == "Contributor"))
                        {
                            $sortHeader = array("Title" => array("TA","TD"), "Artist" => array("AA","AD"), "Contribution" => array("CA","CD"));
                            $rows;

                            if (isset($_POST["Sort"]))
                            {
                                if ($_POST["Sort"] == "TA")
                                {
                                    $SCTA->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCTA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "TD")
                                {
                                    $SCTD->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCTD->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AA")
                                {
                                    $SCAA->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCAA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "AD")
                                {
                                    $SCAD->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCAD->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "CA")
                                {
                                    $SCCA->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCCA->fetchAll(PDO::FETCH_ASSOC);
                                }
                                elseif ($_POST["Sort"] == "CD")
                                {
                                    $SCCD->execute(array(":c" => $_POST["Input"]));
                                    $rows = $SCCD->fetchAll(PDO::FETCH_ASSOC);
                                }
                            }
                            else
                            {
                                $SC->execute(array(":c" => $_POST["Input"]));
                                $rows = $SC->fetchAll(PDO::FETCH_ASSOC);
                            }
                                
                            draw_sort_table_buttons($rows, "sID", "Select", $sortHeader);
                        }
                    }
                    else
                    {
                        echo "<p>Try searching David Bowie in Contributor or Mott the Hoople in Artist</p>";
                    }
                }
                else
                {
                    $sortHeader = array("Title" => array("TA","TD"), "Artist" => array("AA","AD"));
                    $rows;

                    if (isset($_POST["Sort"]))
                    {
                        if ($_POST["Sort"] == "TA")
                        {
                            $SLTA->execute();
                            $rows = $SLTA->fetchAll(PDO::FETCH_ASSOC);
                        }
                        elseif ($_POST["Sort"] == "TD")
                        {
                            $SLTD->execute();
                            $rows = $SLTD->fetchAll(PDO::FETCH_ASSOC);
                        }
                        elseif ($_POST["Sort"] == "AA")
                        {
                            $SLAA->execute();
                            $rows = $SLAA->fetchAll(PDO::FETCH_ASSOC);
                        }
                        elseif ($_POST["Sort"] == "AD")
                        {
                            $SLAD->execute();
                            $rows = $SLAD->fetchAll(PDO::FETCH_ASSOC);
                        }
                    }
                    else
                    {
                        $SL->execute();
                        $rows = $SL->fetchAll(PDO::FETCH_ASSOC);
                    }
                        
                    draw_sort_table_buttons($rows, "sID", "Select", $sortHeader);
                }

                echo "</form>";
            }
            elseif (isset($_POST["User"]))
            {
                echo "<h2>Choose a User<h2>";
                
                $SU->execute();
                $rows = $SU->fetchAll(PDO::FETCH_ASSOC);
                draw_table_buttons($rows, $link, "uID", "Select");
            }
            elseif (isset($_POST["DJ"]))
            {
                echo "<h2>Choose a DJ<h2>";
                
                $SD->execute();
                $rows = $SD->fetchAll(PDO::FETCH_ASSOC);
                draw_table_buttons($rows, $link, "dID", "Select");
            }
            elseif (isset($_POST["fqID"]))
            {
                $GFQ->execute(array(":fqID" => $_POST["fqID"]));
                $data = $GFQ->fetch();

                echo "<p>" . $data["Username"] . " has been selected to sing " . $data["Title"] . " by " . $data["Artist"] . "<p>";
                echo "<p>Version: " . $data["Version"] . "<p>";
                echo "<p>All subsiquent data will be removed from the Free Queue<p>";

                $DFQ->execute(array(":fqID" => $_POST["fqID"]));
            }
            elseif (isset($_POST["pqID"]))
            {
                $GPQ->execute(array(":pqID" => $_POST["pqID"]));
                $data = $GPQ->fetch();

                echo "<p>" . $data["Username"] . ' has paid $' . $data["Amount"] . " to sing " . $data["Title"] . " by " . $data["Artist"] . "<p>";
                echo "<p>Version: " . $data["Version"] . "<p>";
                echo "<p>(All subsiquent data will be removed from the Paid Queue)<p>";

                $DPQ->execute(array(":pqID" => $_POST["pqID"]));
            }
            elseif (isset($_POST["dID"]))
            {
                echo "<h2>Choose someone to sing<h2>";

                echo "<h3>Paid Queue<h3>";
                
                echo "<form action=\"" . $link . "\" method=\"Post\">";
                echo "<input type=\"hidden\" name=\"dID\" value=\"" . $_POST["dID"] .  "\">";
                if (isset($_POST["Sort"]))
                {
                    $PQS->execute();
                    $rows = $PQS->fetchAll(PDO::FETCH_ASSOC);
                    draw_paid_queue_table($rows, $link);
                }
                else
                {
                    $PQ->execute();
                    $rows = $PQ->fetchAll(PDO::FETCH_ASSOC);
                    draw_paid_queue_table($rows, $link);
                }
                echo "</form>";

                echo "<h3>Free Queue<h3>";
                $FQ->execute();
                $rows = $FQ->fetchAll(PDO::FETCH_ASSOC);
                draw_table_buttons($rows, $link, "fqID", "Select");
                echo "<br/>";
            }
            else
            {
                Main_Menu($link);
            }

            echo "<form action=\"" . $link . "\" method=\"Post\">";
            echo '<button type="submit" name="Reset">Start Over</button>';
            echo '</form>';
        ?>
    </body>
</html>