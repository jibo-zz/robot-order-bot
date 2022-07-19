*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Variables ***
${GLOBAL_RETRY_AMOUNT}              3x
${GLOBAL_RETRY_INTERVAL}            10s
${IMAGE_TEMP_OUTPUT_DIRECTORY}      ${CURDIR}${/}image_temp
${PDF_TEMP_OUTPUT_DIRECTORY}        ${CURDIR}${/}pdf_temp


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open The Robot Order Website
    Download The Order Csv File
    Read The Order As A Table And Fill The Order List
    Create Zip Package From Pdf Files
    [Teardown]    Cleanup Temporary Directory And Close The Browser


*** Keywords ***
Open The Robot Order Website
    Open Available Browser    url=https://robotsparebinindustries.com/#/robot-order

Download The Order Csv File
    ${csv_file_url}=    Collect Csv File Url
    Download    ${csv_file_url}

Read The Order As A Table And Fill The Order List
    ${orders}=    Read table from CSV    orders.csv    header=True
    FOR    ${order}    IN    @{orders}
        Close The Annoying Modal
        Fill And Submit The Order For One Robot    ${order}
    END

Close The Annoying Modal
    Click Element    alias:OK

Fill And Submit The Order For One Robot
    [Arguments]    ${order}
    Select From List By Value    id:head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    ${id}=    Get Element Attribute    xpath: //label[contains(text(), "Legs")]    for
    Input Text    id:${id}    ${order}[Legs]
    Input Text    id:address    ${order}[Address]
    Preview And Order
    Collect The Results And Export As A Pdf    ${order}

Preview And Order
    Click Element    id:preview
    Wait Until Keyword Succeeds    ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Order

Order
    Click Button    id:order
    Wait Until Page Contains Element    xpath://*[@id="receipt"]

Collect The Results And Export As A Pdf
    [Arguments]    ${order}
    Screenshot    locator=xpath://div[@id="robot-preview-image"]    filename=${IMAGE_TEMP_OUTPUT_DIRECTORY}${/}robot-order-preview-${order}[Order number].PNG
    ${robot_receipt}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${robot_receipt}    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}robot-${order}[Order number]-receipt.pdf
    ${PDF}=    Open Pdf    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}robot-${order}[Order number]-receipt.pdf
    ${LIST}=    Create List    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}robot-${order}[Order number]-receipt.pdf    ${IMAGE_TEMP_OUTPUT_DIRECTORY}${/}robot-order-preview-${order}[Order number].PNG
    Add Files To Pdf    files=${LIST}    target_document=${PDF_TEMP_OUTPUT_DIRECTORY}${/}robot-${order}[Order number]-receipt.pdf
    Close Pdf    source_pdf=${PDF}
    Wait Until Keyword Succeeds    ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Re-Order

Re-Order
    Click Button    id:order-another

Create Zip Package From Pdf Files
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/ROBOTs.zip
    Archive Folder With Zip    ${PDF_TEMP_OUTPUT_DIRECTORY}    ${zip_file_name}

Cleanup Temporary Directory And Close The Browser
    Remove Directory    ${IMAGE_TEMP_OUTPUT_DIRECTORY}    recursive=True
    Remove Directory    ${PDF_TEMP_OUTPUT_DIRECTORY}    recursive=True
    Close Browser

Collect Csv File Url
    Add icon    Warning
    Add heading    If you like to enter the CSV file URL Press Yes
    Add heading    Or else you want get it from Vault Press No
    Add submit buttons    No,Yes    default=Yes
    ${result}=    Run dialog
    IF    $result.submit == "Yes"
        ${csv}=    Collect Csv File Url From The User
        RETURN    ${csv}
    ELSE IF    $result.submit == "No"
        ${csv}=    Collect Csv File Url From The Vault
        RETURN    ${csv}
    END

Collect Csv File Url From The User
    Add heading    Add URL Of The CSV File    size=Large
    Add text input    url    label=Order CSV URL
    ${response}=    Run dialog
    RETURN    ${response.url}

Collect Csv File Url From The Vault
    ${secret}=    Get Secret    robot_csv_url
    RETURN    ${secret}[url]
