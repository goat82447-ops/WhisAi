param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\demo")
)

$ErrorActionPreference = "Stop"

function Get-Rgb([int]$Red, [int]$Green, [int]$Blue) {
    return $Red + ($Green * 256) + ($Blue * 65536)
}

function Add-Text($Slide, [string]$Text, [float]$Left, [float]$Top, [float]$Width, [float]$Height, [float]$Size, [int]$Color, [int]$Alignment = 1, [bool]$Bold = $false) {
    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.TextFrame2.VerticalAnchor = 3
    $shape.TextFrame2.TextRange.Text = $Text
    $shape.TextFrame2.TextRange.Font.Name = "Aptos"
    $shape.TextFrame2.TextRange.Font.Size = $Size
    $shape.TextFrame2.TextRange.Font.Bold = if ($Bold) { -1 } else { 0 }
    $shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $Color
    $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = $Alignment
    return $shape
}

function Add-Box($Slide, [float]$Left, [float]$Top, [float]$Width, [float]$Height, [int]$Fill, [int]$Line, [float]$RadiusType = 5) {
    $shape = $Slide.Shapes.AddShape($RadiusType, $Left, $Top, $Width, $Height)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Line.ForeColor.RGB = $Line
    $shape.Line.Weight = 1.2
    return $shape
}

function Add-Pill($Slide, [string]$Text, [float]$Left, [float]$Top, [float]$Width, [int]$Fill, [int]$TextColor) {
    $null = Add-Box $Slide $Left $Top $Width 28 $Fill $Fill 5
    $null = Add-Text $Slide $Text $Left $Top $Width 28 11 $TextColor 2 $true
}

function Add-Header($Slide, [string]$Step, [string]$Title, [string]$Subtitle) {
    Add-Pill $Slide $Step 58 38 112 $script:Green $script:White
    $null = Add-Text $Slide $Title 58 82 844 55 29 $script:Ink 1 $true
    $null = Add-Text $Slide $Subtitle 58 137 844 35 15 $script:Muted 1 $false
}

function Add-Arrow($Slide, [float]$X1, [float]$Y1, [float]$X2, [float]$Y2, [int]$Color) {
    $line = $Slide.Shapes.AddLine($X1, $Y1, $X2, $Y2)
    $line.Line.ForeColor.RGB = $Color
    $line.Line.Weight = 2.5
    $line.Line.EndArrowheadStyle = 3
}

function Add-Person($Slide, [float]$Left, [float]$Top, [string]$Label, [int]$Accent) {
    $head = $Slide.Shapes.AddShape(9, $Left + 42, $Top, 44, 44)
    $head.Fill.ForeColor.RGB = $Accent
    $head.Line.Visible = 0
    $body = $Slide.Shapes.AddShape(5, $Left + 20, $Top + 52, 88, 68)
    $body.Fill.ForeColor.RGB = $Accent
    $body.Line.Visible = 0
    $null = Add-Text $Slide $Label $Left ($Top + 128) 128 28 12 $script:Ink 2 $true
}

function Write-FourCc([System.IO.BinaryWriter]$Writer, [string]$Value) {
    $Writer.Write([Text.Encoding]::ASCII.GetBytes($Value))
}

function Set-UInt32([System.IO.BinaryWriter]$Writer, [long]$Position, [uint32]$Value) {
    $currentPosition = $Writer.BaseStream.Position
    $Writer.BaseStream.Position = $Position
    $Writer.Write($Value)
    $Writer.BaseStream.Position = $currentPosition
}

function Convert-FramesToMjpegAvi([string]$FrameDirectory, [string]$OutputPath) {
    Add-Type -AssemblyName System.Drawing

    $frames = [Collections.Generic.List[byte[]]]::new()
    for ($slideNumber = 1; $slideNumber -le 6; $slideNumber++) {
        $imagePath = Join-Path $FrameDirectory "Slide$slideNumber.PNG"
        if (-not (Test-Path $imagePath)) { throw "Missing exported frame: $imagePath" }

        $image = [Drawing.Image]::FromFile($imagePath)
        try {
            $memory = [IO.MemoryStream]::new()
            try {
                $image.Save($memory, [Drawing.Imaging.ImageFormat]::Jpeg)
                $jpeg = $memory.ToArray()
            }
            finally { $memory.Dispose() }
        }
        finally { $image.Dispose() }

        for ($second = 0; $second -lt 5; $second++) { $frames.Add($jpeg) }
    }

    $width = 1920
    $height = 1080
    $framesPerSecond = 1
    $largestFrame = ($frames | ForEach-Object Length | Measure-Object -Maximum).Maximum
    $stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    $writer = [IO.BinaryWriter]::new($stream)

    try {
        Write-FourCc $writer "RIFF"
        $riffSizePosition = $stream.Position
        $writer.Write([uint32]0)
        Write-FourCc $writer "AVI "

        Write-FourCc $writer "LIST"
        $headerListSizePosition = $stream.Position
        $writer.Write([uint32]0)
        Write-FourCc $writer "hdrl"

        Write-FourCc $writer "avih"
        $writer.Write([uint32]56)
        $writer.Write([uint32]1000000)
        $writer.Write([uint32]($largestFrame * $framesPerSecond))
        $writer.Write([uint32]0)
        $writer.Write([uint32]0x10)
        $writer.Write([uint32]$frames.Count)
        $writer.Write([uint32]0)
        $writer.Write([uint32]1)
        $writer.Write([uint32]$largestFrame)
        $writer.Write([uint32]$width)
        $writer.Write([uint32]$height)
        1..4 | ForEach-Object { $writer.Write([uint32]0) }

        Write-FourCc $writer "LIST"
        $streamListSizePosition = $stream.Position
        $writer.Write([uint32]0)
        Write-FourCc $writer "strl"

        Write-FourCc $writer "strh"
        $writer.Write([uint32]56)
        Write-FourCc $writer "vids"
        Write-FourCc $writer "MJPG"
        $writer.Write([uint32]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint32]0)
        $writer.Write([uint32]1)
        $writer.Write([uint32]$framesPerSecond)
        $writer.Write([uint32]0)
        $writer.Write([uint32]$frames.Count)
        $writer.Write([uint32]$largestFrame)
        $writer.Write([int32]-1)
        $writer.Write([uint32]0)
        $writer.Write([int16]0)
        $writer.Write([int16]0)
        $writer.Write([int16]$width)
        $writer.Write([int16]$height)

        Write-FourCc $writer "strf"
        $writer.Write([uint32]40)
        $writer.Write([uint32]40)
        $writer.Write([int32]$width)
        $writer.Write([int32]$height)
        $writer.Write([uint16]1)
        $writer.Write([uint16]24)
        Write-FourCc $writer "MJPG"
        $writer.Write([uint32]$largestFrame)
        $writer.Write([int32]0)
        $writer.Write([int32]0)
        $writer.Write([uint32]0)
        $writer.Write([uint32]0)

        $streamListEnd = $stream.Position
        Set-UInt32 $writer $streamListSizePosition ([uint32]($streamListEnd - $streamListSizePosition - 4))
        Set-UInt32 $writer $headerListSizePosition ([uint32]($streamListEnd - $headerListSizePosition - 4))

        Write-FourCc $writer "LIST"
        $movieListSizePosition = $stream.Position
        $writer.Write([uint32]0)
        Write-FourCc $writer "movi"
        $movieDataStart = $stream.Position
        $indexEntries = [Collections.Generic.List[object]]::new()

        foreach ($frame in $frames) {
            $chunkPosition = $stream.Position
            Write-FourCc $writer "00dc"
            $writer.Write([uint32]$frame.Length)
            $writer.Write($frame)
            if (($frame.Length % 2) -ne 0) { $writer.Write([byte]0) }
            $indexEntries.Add([PSCustomObject]@{ Offset = [uint32]($chunkPosition - $movieDataStart); Size = [uint32]$frame.Length })
        }

        $movieListEnd = $stream.Position
        Set-UInt32 $writer $movieListSizePosition ([uint32]($movieListEnd - $movieListSizePosition - 4))

        Write-FourCc $writer "idx1"
        $writer.Write([uint32]($indexEntries.Count * 16))
        foreach ($entry in $indexEntries) {
            Write-FourCc $writer "00dc"
            $writer.Write([uint32]0x10)
            $writer.Write($entry.Offset)
            $writer.Write($entry.Size)
        }

        Set-UInt32 $writer $riffSizePosition ([uint32]($stream.Length - 8))
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

$script:Ink = Get-Rgb 20 28 24
$script:Muted = Get-Rgb 91 105 96
$script:Paper = Get-Rgb 247 249 245
$script:White = Get-Rgb 255 255 255
$script:Green = Get-Rgb 29 105 72
$script:Mint = Get-Rgb 222 238 228
$script:Coral = Get-Rgb 235 112 86
$script:Blue = Get-Rgb 48 104 185
$script:Line = Get-Rgb 211 220 213
$script:Dark = Get-Rgb 15 22 19

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$presentationPath = Join-Path $OutputDirectory "KrishAI-Sharing-Explained.pptx"
$videoPath = Join-Path $OutputDirectory "KrishAI-Sharing-Explained.avi"
$frameDirectory = Join-Path $OutputDirectory "sharing-demo-frames"

$powerPoint = $null
$presentation = $null

try {
    $powerPoint = New-Object -ComObject PowerPoint.Application
    $powerPoint.Visible = -1
    $presentation = $powerPoint.Presentations.Add()
    $presentation.PageSetup.SlideSize = 15

    # 1. Introduction
    $slide = $presentation.Slides.Add(1, 12)
    $background = Add-Box $slide 0 0 960 540 $script:Dark $script:Dark 1
    $background.Line.Visible = 0
    $background.ZOrder(1)
    Add-Pill $slide "KRISHAI PRIVACY GUIDE" 58 54 190 $script:Green $script:White
    $null = Add-Text $slide "What does an outside person see?" 58 124 844 85 35 $script:White 1 $true
    $null = Add-Text $slide "A clear comparison of no sharing, KrishAI screen context, and Teams or Meet sharing." 58 214 760 60 18 (Get-Rgb 190 204 195) 1 $false
    $null = Add-Box $slide 58 322 844 150 (Get-Rgb 28 38 33) (Get-Rgb 52 70 60) 5
    $null = Add-Text $slide "KEY RULE" 86 344 140 26 11 $script:Coral 1 $true
    $null = Add-Text $slide "Only what you choose to share leaves your screen.`nUnshared windows stay outside that sharing path." 86 370 760 76 18 $script:White 1 $true

    # 2. No sharing
    $slide = $presentation.Slides.Add(2, 12)
    $slide.Background.Fill.ForeColor.RGB = $script:Paper
    Add-Header $slide "STATE 1" "No screen sharing" "KrishAI is open, but neither screen-sharing path is active."
    $null = Add-Box $slide 58 210 390 240 $script:White $script:Line 5
    $null = Add-Text $slide "YOUR COMPUTER" 84 230 336 24 11 $script:Muted 1 $true
    $null = Add-Box $slide 84 270 336 130 (Get-Rgb 232 237 233) $script:Line 1
    $null = Add-Text $slide "KrishAI\nPrivate local window" 105 292 294 84 18 $script:Ink 2 $true
    $null = Add-Box $slide 512 210 390 240 $script:White $script:Line 5
    Add-Person $slide 640 258 "Outside participant" $script:Blue
    $null = Add-Text $slide "Sees only camera or content already shared in the meeting." 548 400 318 35 13 $script:Muted 2 $false
    $null = Add-Text $slide "No KrishAI snapshot is sent" 58 480 844 36 18 $script:Green 2 $true

    # 3. KrishAI picker
    $slide = $presentation.Slides.Add(3, 12)
    $slide.Background.Fill.ForeColor.RGB = $script:Paper
    Add-Header $slide "STATE 2" "You press Share screen in KrishAI" "The browser opens a system picker. Nothing is captured until you choose a source."
    $null = Add-Box $slide 105 205 750 275 $script:White $script:Line 5
    $null = Add-Text $slide "Choose what to share with KrishAI" 136 228 688 34 19 $script:Ink 1 $true
    $choices = @(
        @{ X = 136; Label = "Entire screen"; Color = $script:Blue },
        @{ X = 354; Label = "App window"; Color = $script:Green },
        @{ X = 572; Label = "Browser tab"; Color = $script:Coral }
    )
    foreach ($choice in $choices) {
        $null = Add-Box $slide $choice.X 286 190 112 (Get-Rgb 241 244 241) $script:Line 1
        $null = Add-Box $slide ($choice.X + 20) 304 150 62 $choice.Color $choice.Color 1
        $null = Add-Text $slide $choice.Label $choice.X 407 190 24 12 $script:Ink 2 $true
    }
    $null = Add-Text $slide "You remain in control: Cancel sends nothing." 105 494 750 30 15 $script:Muted 2 $false

    # 4. KrishAI active sharing
    $slide = $presentation.Slides.Add(4, 12)
    $slide.Background.Fill.ForeColor.RGB = $script:Paper
    Add-Header $slide "STATE 3" "KrishAI sharing is active" "A visible indicator stays on. A snapshot is attached only when you submit a question."
    $null = Add-Box $slide 58 220 235 205 $script:White $script:Line 5
    $null = Add-Text $slide "SELECTED SOURCE" 80 240 191 24 11 $script:Muted 2 $true
    $null = Add-Box $slide 80 280 191 105 $script:Blue $script:Blue 1
    $null = Add-Text $slide "Your chosen\nscreen or window" 92 296 167 70 16 $script:White 2 $true
    Add-Arrow $slide 300 322 414 322 $script:Green
    $null = Add-Box $slide 420 244 220 155 $script:Mint $script:Green 5
    $null = Add-Text $slide "KrishAI API\nSnapshot + question" 438 274 184 92 18 $script:Ink 2 $true
    Add-Arrow $slide 647 322 744 322 $script:Green
    $null = Add-Box $slide 750 244 152 155 $script:White $script:Line 5
    $null = Add-Text $slide "Configured\nAI provider" 765 274 122 92 17 $script:Ink 2 $true
    Add-Pill $slide "NOT SENT TO THE MEETING PARTICIPANT" 246 462 468 (Get-Rgb 252 230 224) $script:Coral

    # 5. Meeting sharing
    $slide = $presentation.Slides.Add(5, 12)
    $slide.Background.Fill.ForeColor.RGB = $script:Paper
    Add-Header $slide "STATE 4" "You share in Teams, Zoom, or Meet" "The meeting app selection, not KrishAI, decides what the outside participant receives."
    $null = Add-Box $slide 58 215 390 235 $script:White $script:Line 5
    $null = Add-Text $slide "SHARE A WINDOW" 82 236 342 24 11 $script:Green 2 $true
    $null = Add-Box $slide 90 280 326 95 $script:Blue $script:Blue 1
    $null = Add-Text $slide "Only that selected app window" 104 298 298 58 17 $script:White 2 $true
    $null = Add-Text $slide "Most predictable option" 82 397 342 25 13 $script:Muted 2 $false
    $null = Add-Box $slide 512 215 390 235 $script:White $script:Line 5
    $null = Add-Text $slide "SHARE AN ENTIRE DISPLAY" 536 236 342 24 11 $script:Coral 2 $true
    $null = Add-Box $slide 544 280 326 95 (Get-Rgb 232 237 233) $script:Line 1
    $null = Add-Text $slide "Everything visible on that display" 558 298 298 58 17 $script:Ink 2 $true
    $null = Add-Text $slide "Protected KrishAI may be blank or omitted on supported capture paths." 536 390 342 46 12 $script:Muted 2 $false
    $null = Add-Text $slide "Always verify in the meeting preview before sharing." 58 482 844 34 16 $script:Coral 2 $true

    # 6. Summary
    $slide = $presentation.Slides.Add(6, 12)
    $slide.Background.Fill.ForeColor.RGB = $script:Dark
    $null = Add-Text $slide "Before you share" 58 54 844 55 30 $script:White 1 $true
    $items = @(
        "1   Choose a single app window when possible.",
        "2   Check the meeting preview from a second device or participant.",
        "3   Keep the green Privacy protection on indicator visible.",
        "4   Stop KrishAI screen context when you no longer need it."
    )
    $top = 142
    foreach ($item in $items) {
        $null = Add-Box $slide 58 $top 844 64 (Get-Rgb 28 38 33) (Get-Rgb 52 70 60) 5
        $null = Add-Text $slide $item 84 ($top + 8) 790 48 17 $script:White 1 $false
        $top += 78
    }
    $null = Add-Text $slide "Privacy protection is supported-path behavior, not a guarantee against every capture method." 58 474 844 38 13 (Get-Rgb 190 204 195) 2 $false

    foreach ($currentSlide in $presentation.Slides) {
        $currentSlide.SlideShowTransition.AdvanceOnTime = -1
        $currentSlide.SlideShowTransition.AdvanceTime = 5
        $currentSlide.SlideShowTransition.EntryEffect = 3849
    }

    $presentation.SaveAs($presentationPath, 24)
    New-Item -ItemType Directory -Path $frameDirectory -Force | Out-Null
    $presentation.Export($frameDirectory, "PNG", 1920, 1080)
}
finally {
    if ($presentation) {
        try { $presentation.Close() } catch { }
        [Runtime.InteropServices.Marshal]::ReleaseComObject($presentation) | Out-Null
    }
    if ($powerPoint) {
        $powerPoint.Quit()
        [Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

if (Test-Path $videoPath) { Remove-Item $videoPath -Force }
Convert-FramesToMjpegAvi $frameDirectory $videoPath

if (-not (Test-Path $videoPath) -or (Get-Item $videoPath).Length -eq 0) {
    throw "The built-in encoder did not produce a usable AVI file."
}

Get-Item $presentationPath, $videoPath | Select-Object FullName, Length, LastWriteTime