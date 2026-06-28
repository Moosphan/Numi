import XCTest
final class NumiUITests: XCTestCase {
    private var uiTestStoreID: String!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        uiTestStoreID = UUID().uuidString
    }

    func testTabsAndAddRecordSheetAreReachable() {
        let app = launchApp()

        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
    }

    func testPrimaryTabsCanBeSelected() {
        let app = launchApp()

        for tab in ["洞悉", "计划", "我的", "明细"] {
            let button = tabButton(tab, in: app)
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
    }

    func testCanSwitchAppLanguageAtRuntimeFromSettings() {
        let app = launchApp()

        waitForLabel("明细", on: app.buttons["tab.transactions"])
        waitForLabel("洞悉", on: app.buttons["tab.insights"])
        waitForLabel("计划", on: app.buttons["tab.plans"])
        waitForLabel("我的", on: app.buttons["tab.settings"])

        app.buttons["tab.settings"].tap()
        let settingsScroll = app.scrollViews["scroll.settingsHome"]
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))

        let languageRow = app.buttons["settings.language"]
        if languageRow.exists && !languageRow.isHittable {
            settingsScroll.swipeUp()
        }
        XCTAssertTrue(languageRow.waitForExistence(timeout: 5), "settings.language button should exist")
        languageRow.tap()

        let englishOption = app.buttons["language.en"]
        XCTAssertTrue(englishOption.waitForExistence(timeout: 5))
        englishOption.tap()

        // 语言切换后根视图 .id(languageCode) 重建，导航回到首页，重新进入设置页
        waitForLabel("Transactions", on: app.buttons["tab.transactions"])
        waitForLabel("Insights", on: app.buttons["tab.insights"])
        waitForLabel("Plans", on: app.buttons["tab.plans"])
        waitForLabel("Settings", on: app.buttons["tab.settings"])

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))

        waitForLabel("Data", on: app.staticTexts["settings.section.data"])
        waitForLabel("Security", on: app.staticTexts["settings.section.security"])
        waitForLabel("Appearance", on: app.staticTexts["settings.section.appearance"])
        waitForLabel("Theme", on: app.buttons["settings.theme"])
        waitForLabel("Multi-Currency", on: app.buttons["settings.currency"])

        app.buttons["tab.insights"].tap()
        XCTAssertTrue(app.staticTexts["summary.insights.expense.value"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["summary.insights.income.value"].waitForExistence(timeout: 5))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(languageRow.waitForExistence(timeout: 5))
        languageRow.tap()

        let chineseOption = app.buttons["language.zh-Hans"]
        XCTAssertTrue(chineseOption.waitForExistence(timeout: 5))
        chineseOption.tap()

        // 语言切换后根视图 .id(languageCode) 重建，导航回到首页，重新进入设置页
        waitForLabel("明细", on: app.buttons["tab.transactions"])
        waitForLabel("洞悉", on: app.buttons["tab.insights"])
        waitForLabel("计划", on: app.buttons["tab.plans"])
        waitForLabel("我的", on: app.buttons["tab.settings"])

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))

        waitForLabel("数据", on: app.staticTexts["settings.section.data"])
        waitForLabel("安全", on: app.staticTexts["settings.section.security"])
        waitForLabel("外观", on: app.staticTexts["settings.section.appearance"])
        waitForLabel("主题", on: app.buttons["settings.theme"])
        waitForLabel("多货币管理", on: app.buttons["settings.currency"])
    }

    func testBottomBarUsesFourTabsPlusTrailingAddButtonLayout() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let addButton = app.buttons["button.addRecord"]
        let settingsTab = tabButton("我的", in: app)
        let transactionsTab = tabButton("明细", in: app)
        let plansTab = tabButton("计划", in: app)

        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 5))
        XCTAssertTrue(plansTab.waitForExistence(timeout: 5))

        let rail = app.otherElements["tab.rail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))

        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertGreaterThan(addButton.frame.minX, rail.frame.maxX)
        XCTAssertLessThan(fabs(addButton.frame.midY - rail.frame.midY), 10)
        XCTAssertEqual(addButton.value as? String, "tintedGlassChrome|pencil|darkIcon")
    }

    func testSecondaryPageHidesBottomBarAndReturningRestoresIt() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        assertBottomBarVisible(in: app)
        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame

        tabButton("我的", in: app).tap()
        let categoriesEntry = app.buttons["settings.categories"]
        XCTAssertTrue(categoriesEntry.waitForExistence(timeout: 5))
        categoriesEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.categoryManagement"].waitForExistence(timeout: 5))
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)

        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.scrollViews["scroll.settingsHome"].waitForExistence(timeout: 5))
        assertBottomBarVisible(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testTransactionsHomeScrollHidesAndRevealsBottomBar() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let addButton = app.buttons["button.addRecord"]
        let homeScrollView = app.scrollViews["scroll.transactionsHome"]

        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(homeScrollView.waitForExistence(timeout: 5))
        let baselineAddButtonFrame = addButton.frame

        homeScrollView.swipeUp()

        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)

        homeScrollView.swipeDown()

        assertBottomBarVisible(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testTransactionsHomeScrollMovesBottomBarOffscreenAndBack() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let homeScrollView = app.scrollViews["scroll.transactionsHome"]
        XCTAssertTrue(homeScrollView.waitForExistence(timeout: 5))

        assertBottomBarVisible(in: app)
        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame

        homeScrollView.swipeUp()
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)

        homeScrollView.swipeDown()
        assertBottomBarVisible(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testCategoryManagementPageHidesBottomBarImmediately() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        let categoriesEntry = app.buttons["settings.categories"]
        XCTAssertTrue(categoriesEntry.waitForExistence(timeout: 5))
        categoriesEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.categoryManagement"].waitForExistence(timeout: 5))
        let categoryScrollView = app.scrollViews["scroll.categoryManagement"]
        XCTAssertTrue(categoryScrollView.waitForExistence(timeout: 5))

        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testAccountManagementPageHidesBottomBarImmediately() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        let accountsEntry = app.buttons["settings.accounts"]
        XCTAssertTrue(accountsEntry.waitForExistence(timeout: 5))
        accountsEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.accountManagement"].waitForExistence(timeout: 5))
        let accountScrollView = app.scrollViews["scroll.accountManagement"]
        XCTAssertTrue(accountScrollView.waitForExistence(timeout: 5))

        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testThirdLevelPageAlsoKeepsBottomBarHidden() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        assertBottomBarVisible(in: app)
        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame

        tabButton("我的", in: app).tap()
        let accountsEntry = app.buttons["settings.accounts"]
        XCTAssertTrue(accountsEntry.waitForExistence(timeout: 5))
        accountsEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.accountManagement"].waitForExistence(timeout: 5))
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)

        let accountDetailEntry = accountButton("银行卡", in: app)
        XCTAssertTrue(accountDetailEntry.waitForExistence(timeout: 5))
        accountDetailEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.accountDetail"].waitForExistence(timeout: 5))
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testSettingsSecuritySectionKeepsComfortableGapAboveBottomBar() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()

        let securityHeader = app.staticTexts["settings.section.security"]
        let settingsTab = tabButton("我的", in: app)

        XCTAssertTrue(securityHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))

        XCTAssertGreaterThan(settingsTab.frame.minY - securityHeader.frame.maxY, 10)
    }

    func testAddingExpenseAppearsInTransactionsList() {
        let app = launchApp()

        addFoodExpense(in: app)

        XCTAssertSavedFoodExpenseExists(in: app)
    }

    func testAddedExpensePersistsAfterRelaunch() {
        let app = launchApp()

        addFoodExpense(in: app)
        app.terminate()
        app.launch()

        XCTAssertSavedFoodExpenseExists(in: app)
    }

    func testDeletingExpenseCanBeUndone() {
        let app = launchApp()

        addFoodExpense(in: app)
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["action.context.deleteRecord"].waitForExistence(timeout: 5))
        app.buttons["action.context.deleteRecord"].tap()
        XCTAssertTrue(app.buttons["action.confirmDeleteRecord"].waitForExistence(timeout: 5))
        app.buttons["action.confirmDeleteRecord"].tap()

        XCTAssertFalse(savedRecord.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["action.undoDeleteRecord"].waitForExistence(timeout: 5))
        app.buttons["action.undoDeleteRecord"].tap()

        XCTAssertSavedFoodExpenseExists(in: app)
    }

    func testEditingExpenseUpdatesList() {
        let app = launchApp()

        addFoodExpense(in: app)
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥12.00"].waitForExistence(timeout: 5))
        app.buttons["action.editRecord"].tap()

        XCTAssertTrue(app.buttons["picker.editRecordCategory"].waitForExistence(timeout: 5))
        app.buttons["picker.editRecordCategory"].tap()
        XCTAssertTrue(categoryButton("交通", in: app).waitForExistence(timeout: 5))
        categoryButton("交通", in: app).tap()
        app.buttons["keypad.delete"].tap()
        app.buttons["keypad.delete"].tap()
        app.buttons["keypad.3"].tap()
        app.buttons["keypad.4"].tap()
        app.buttons["action.submitRecord"].tap()

        XCTAssertTrue(recordElement("交通", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(recordAmountElement("交通", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(recordElement("餐饮", in: app).waitForExistence(timeout: 2))
    }

    func testSearchingTransactionsFiltersAndClearsResults() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"])
        addExpense(in: app, categoryName: "交通", amountDigits: ["3", "4"])

        XCTAssertTrue(recordElement("餐饮", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(recordElement("交通", in: app).waitForExistence(timeout: 5))

        app.buttons["action.openTransactionSearch"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("交通")

        XCTAssertTrue(searchRecordElement("交通", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(searchRecordElement("餐饮", in: app).waitForExistence(timeout: 2))

        searchField.clearText()
        XCTAssertTrue(searchRecordElement("餐饮", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(searchRecordElement("交通", in: app).waitForExistence(timeout: 5))
    }

    func testSearchPresentedFromFullScreenPageHidesHomeAddButton() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let baselineAddButtonFrame = app.buttons["button.addRecord"].frame
        assertBottomBarVisible(in: app)
        app.buttons["action.openTransactionSearch"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        assertBottomBarHiddenAfterScroll(in: app, baselineAddButtonFrame: baselineAddButtonFrame)
    }

    func testSearchKeyboardDoesNotLiftBottomTabBar() {
        let app = launchApp()

        let searchButton = app.buttons["action.openTransactionSearch"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        let beforeMinY = searchButton.frame.minY

        searchButton.tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        let searchPage = app.otherElements["page.transactionSearch"]
        XCTAssertTrue(searchPage.waitForExistence(timeout: 5))
        let afterMinY = searchPage.frame.minY

        XCTAssertLessThan(fabs(afterMinY - beforeMinY), 24)
    }

    func testTopLevelPagesShowNativeNavigationTitles() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        XCTAssertTrue(tabButton("洞悉", in: app).waitForExistence(timeout: 5))
        tabButton("洞悉", in: app).tap()
        XCTAssertTrue(app.navigationBars["洞悉"].waitForExistence(timeout: 5))

        tabButton("计划", in: app).tap()
        XCTAssertTrue(app.navigationBars["计划"].waitForExistence(timeout: 5))

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 5))
    }

    func testThemeSelectionPageAllowsSwitchingThemes() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        let themeEntry = app.descendants(matching: .any)["settings.theme"]
        XCTAssertTrue(themeEntry.waitForExistence(timeout: 5))
        themeEntry.tap()

        XCTAssertTrue(app.scrollViews["scroll.themeSelection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme.brandWarm"].waitForExistence(timeout: 5))
        app.buttons["theme.brandWarm"].tap()
        XCTAssertEqual(app.buttons["theme.brandWarm"].value as? String, "selected")
    }

    func testThemeSelectionImmediatelyAppliesThemeAcrossApp() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        let themeEntry = app.descendants(matching: .any)["settings.theme"]
        XCTAssertTrue(themeEntry.waitForExistence(timeout: 5))
        themeEntry.tap()

        XCTAssertTrue(app.buttons["theme.brandWarm"].waitForExistence(timeout: 5))
        app.buttons["theme.brandWarm"].tap()

        let appliedTheme = app.staticTexts["app.theme.active"]
        XCTAssertTrue(appliedTheme.waitForExistence(timeout: 5))
        XCTAssertEqual(appliedTheme.label, "brandWarm")
    }

    func testThemeChangeStaysAppliedWhenOpeningCategorySheet() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        let themeEntry = app.descendants(matching: .any)["settings.theme"]
        XCTAssertTrue(themeEntry.waitForExistence(timeout: 5))
        themeEntry.tap()
        XCTAssertTrue(app.buttons["theme.brandWarm"].waitForExistence(timeout: 5))
        app.buttons["theme.brandWarm"].tap()

        tabButton("明细", in: app).tap()
        tapAddRecord(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecord"].waitForExistence(timeout: 5))
        let appliedTheme = app.staticTexts["app.theme.active"]
        XCTAssertTrue(appliedTheme.waitForExistence(timeout: 5))
        XCTAssertEqual(appliedTheme.label, "brandWarm")
        XCTAssertTrue(app.buttons["action.closeAddRecordSelection"].waitForExistence(timeout: 5))
    }

    func testSearchOpensDedicatedPageWithSystemSearchField() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        XCTAssertTrue(app.buttons["action.openTransactionSearch"].waitForExistence(timeout: 5))
        app.buttons["action.openTransactionSearch"].tap()

        XCTAssertTrue(app.otherElements["page.transactionSearch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["search.transactions"].exists)
    }

    func testAddRecordStartsFromCategorySelectionThenShowsCurrencyPicker() {
        let app = launchApp()

        tapAddRecord(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecord"].waitForExistence(timeout: 5))
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(tabButton("明细", in: app).exists)
        XCTAssertFalse(app.buttons["action.saveRecord"].exists)

        categoryButton("餐饮", in: app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecordEditor"].waitForExistence(timeout: 5))
        let editorTitle = app.staticTexts["sheet.addRecordEditor.title"]
        XCTAssertTrue(editorTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(editorTitle.label.isEmpty)
        XCTAssertTrue(app.buttons["sheet.addRecordEditor.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecord"].exists)
        XCTAssertFalse(app.buttons["picker.recordCurrency"].exists)
        XCTAssertFalse(app.buttons["picker.addRecordDate"].exists)
        XCTAssertTrue(app.buttons["picker.inlineRecordAccount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["picker.inlineRecordCurrency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keypad.openDatePicker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["action.saveAndContinue"].exists)
        XCTAssertTrue(app.buttons["action.submitRecord"].waitForExistence(timeout: 5))
    }

    func testAddRecordUsesKeyboardDatePickerAndNoteShowsSystemKeyboard() {
        let app = launchApp()

        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        categoryButton("餐饮", in: app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecordEditor"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["display.inlineRecordDate"].exists)
        XCTAssertTrue(app.buttons["keypad.openDatePicker"].waitForExistence(timeout: 5))

        let noteField = app.textFields["input.inlineRecordNote"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        noteField.tap()

        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["action.keyboardSubmitRecord"].waitForExistence(timeout: 5))
    }

    func testAddRecordDatePickerUsesCompactThemedSheetToolbar() {
        let app = launchApp()

        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        categoryButton("餐饮", in: app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecordEditor"].waitForExistence(timeout: 5))
        let openDatePickerButton = app.buttons["keypad.openDatePicker"]
        XCTAssertTrue(openDatePickerButton.waitForExistence(timeout: 5))
        openDatePickerButton.tap()

        XCTAssertTrue(app.buttons["sheet.datePicker.cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.datePicker.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sheet.datePicker.title"].waitForExistence(timeout: 5))
    }

    func testDraggingRecordEditorClosesOnlyEditorAndKeepsCategorySheet() {
        let app = launchApp()

        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        categoryButton("餐饮", in: app).tap()

        let editor = app.descendants(matching: .any)["sheet.addRecordEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.swipeDown()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecord"].waitForExistence(timeout: 5))
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["sheet.addRecordEditor"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["sheet.addRecord"].exists)
    }

    func testEmptyHomeStateStillShowsFloatingAddButton() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["home.empty.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["button.addRecord"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.empty.primaryAction"].exists)
    }

    func testLongPressTransactionShowsContextMenuActions() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"])

        let record = recordElement("餐饮", in: app)
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.press(forDuration: 1.1)

        XCTAssertTrue(app.buttons["action.context.editRecord"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["action.context.deleteRecord"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["action.context.shareRecord"].waitForExistence(timeout: 5))
    }

    func testEmptyHomeStateOffersPrimaryAddAction() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["home.empty.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["button.addRecord"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.empty.primaryAction"].exists)
    }

    func testEmptyHomeStateUsesFloatingAddButtonAndBorderlessPrompt() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["home.empty.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.empty.subtitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.empty.primaryAction"].exists)
        XCTAssertTrue(app.buttons["button.addRecord"].waitForExistence(timeout: 5))
    }

    func testInsightsDistributionShowsCategoryNameAndIcon() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("洞悉", in: app).tap()

        XCTAssertTrue(app.staticTexts["insights.distribution.expense"].waitForExistence(timeout: 5))
        let housingRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "住房")).firstMatch
        XCTAssertTrue(housingRow.waitForExistence(timeout: 5))
        XCTAssertTrue(housingRow.images.firstMatch.exists)
    }

    func testAddingEditingAndSearchingTransactionNote() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"], note: "早餐小票")
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["早餐小票"].waitForExistence(timeout: 5))
        app.buttons["action.editRecord"].tap()

        let editNoteField = app.textFields["input.editRecordNote"]
        XCTAssertTrue(editNoteField.waitForExistence(timeout: 5))
        editNoteField.tap()
        app.buttons["action.clearEditRecordNote"].tap()
        editNoteField.typeText("地铁通勤")
        app.buttons["action.submitRecord"].tap()

        XCTAssertTrue(recordElement("餐饮", in: app).waitForExistence(timeout: 5))
        app.buttons["action.openTransactionSearch"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("地铁通勤")

        XCTAssertTrue(recordElement("餐饮", in: app).waitForExistence(timeout: 5))
    }

    func testEditRecordUsesInlineKeyboardStyleControls() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["8", "9"], note: "超市")
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        app.buttons["action.editRecord"].tap()

        XCTAssertTrue(app.scrollViews["page.editRecord"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["picker.recordCurrency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["picker.editRecordAccount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keypad.openDatePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["input.editRecordNote"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["picker.editRecordDate"].exists)
    }

    func testHomePeriodPickerShowsWeekMonthQuarterYearOptions() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let titleButton = app.buttons["home.period.title"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        titleButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.homePeriodPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.period.option.week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.period.option.month"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.period.option.quarter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.period.option.year"].waitForExistence(timeout: 5))
    }

    func testHomePeriodPickerUsesCustomBottomSheetChrome() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let titleButton = app.buttons["home.period.title"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        titleButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.homePeriodPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.homePeriodPicker.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sheet.homePeriodPicker.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["sheet.homePeriodPicker.systemDragIndicator"].exists)
        XCTAssertFalse(app.navigationBars["时间范围"].exists)
    }

    func testPasscodeSheetUsesCustomBottomSheetChromeAndShowsFullKeypad() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.staticTexts["settings.section.security"].waitForExistence(timeout: 5))

        let privacyLockSwitch = app.switches["toggle.privacyLock"]
        XCTAssertTrue(privacyLockSwitch.waitForExistence(timeout: 5))
        if (privacyLockSwitch.value as? String) == "0" {
            privacyLockSwitch.tap()
        } else {
            let lockMethodRow = app.buttons["settings.lockMethod"]
            XCTAssertTrue(lockMethodRow.waitForExistence(timeout: 5))
            lockMethodRow.tap()
        }

        let passcodeOption = app.buttons["sheet.optionSheet.option.passcode"]
        XCTAssertTrue(passcodeOption.waitForExistence(timeout: 5))
        passcodeOption.tap()

        XCTAssertTrue(app.descendants(matching: .any)["sheet.passcode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.passcode.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sheet.passcode.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.passcode.key.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.passcode.key.9"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sheet.passcode.delete"].waitForExistence(timeout: 5))
    }

    func testSettingsUsesCardSectionsWithReadableHeaders() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        tabButton("我的", in: app).tap()

        XCTAssertTrue(app.staticTexts["settings.section.data"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["settings.section.security"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["settings.section.appearance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["settings.card.data"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["settings.card.security"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["settings.card.appearance"].waitForExistence(timeout: 5))
    }

    func testChangingHomePeriodUpdatesCenteredTitle() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let titleButton = app.buttons["home.period.title"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        let initialTitle = titleButton.label

        titleButton.tap()
        let yearOption = app.descendants(matching: .any)["home.period.option.year"]
        XCTAssertTrue(yearOption.waitForExistence(timeout: 5))
        yearOption.tap()

        let updatedTitleButton = app.buttons["home.period.title"]
        XCTAssertTrue(updatedTitleButton.waitForExistence(timeout: 5))
        XCTAssertNotEqual(initialTitle, updatedTitleButton.label)
    }

    func testHomePeriodNavigationMovesBetweenIntervals() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        let titleButton = app.buttons["home.period.title"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        let initialTitle = titleButton.label

        let previousButton = app.buttons["home.period.previous"]
        XCTAssertTrue(previousButton.waitForExistence(timeout: 5))
        previousButton.tap()

        let movedTitle = app.buttons["home.period.title"]
        XCTAssertTrue(movedTitle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(initialTitle, movedTitle.label)

        let nextButton = app.buttons["home.period.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let returnedTitle = app.buttons["home.period.title"]
        XCTAssertTrue(returnedTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(initialTitle, returnedTitle.label)
    }

    func testHomeListShowsDateSectionsInsteadOfDetailTitle() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        XCTAssertTrue(app.descendants(matching: .any)["home.sectionDate.today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.sectionDate.yesterday"].waitForExistence(timeout: 5))
    }

    func testAddingExpenseWithSelectedAccountShowsAccountInDetail() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"], accountName: "银行卡")
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["银行卡"].waitForExistence(timeout: 5))
    }

    func testAddingExpenseWithYesterdayDateShowsDateInDetail() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"], dateShortcut: "昨天")
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))

        savedRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["昨天"].waitForExistence(timeout: 5))
    }

    func testAddingExpenseWithPreviousDateShowsUpOnHomeImmediately() {
        let app = launchApp()

        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"], dateShortcut: "昨天")

        XCTAssertTrue(recordElement("餐饮", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.sectionDate.yesterday"].waitForExistence(timeout: 5))
    }

    func testHiddenExpenseCategoryIsRemovedFromAddRecordGrid() {
        let app = launchApp()

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.buttons["settings.categories"].waitForExistence(timeout: 5))
        app.buttons["settings.categories"].tap()

        XCTAssertTrue(app.scrollViews["scroll.categoryManagement"].waitForExistence(timeout: 5))
        let foodToggle = categoryToggle("餐饮", in: app)
        XCTAssertTrue(foodToggle.waitForExistence(timeout: 5))
        foodToggle.tap()
        XCTAssertEqual(foodToggle.value as? String, "0")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tabButton("明细", in: app).tap()
        tapAddRecord(in: app)

        XCTAssertFalse(categoryButton("餐饮", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(categoryButton("交通", in: app).waitForExistence(timeout: 5))
    }

    func testHiddenAccountIsRemovedFromAddRecordPicker() {
        let app = launchApp()

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.buttons["settings.accounts"].waitForExistence(timeout: 5))
        app.buttons["settings.accounts"].tap()

        XCTAssertTrue(app.scrollViews["scroll.accountManagement"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥0.00"].waitForExistence(timeout: 5))
        let cardToggle = accountToggle("银行卡", in: app)
        XCTAssertTrue(cardToggle.waitForExistence(timeout: 5))
        cardToggle.tap()
        XCTAssertEqual(cardToggle.value as? String, "0")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tabButton("明细", in: app).tap()
        tapAddRecord(in: app)
        XCTAssertTrue(app.buttons["picker.inlineRecordAccount"].waitForExistence(timeout: 5))
        app.buttons["picker.inlineRecordAccount"].tap()

        XCTAssertFalse(accountButton("银行卡", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(accountButton("现金", in: app).waitForExistence(timeout: 5))
    }

    func testCanCreateAndEditAccountFromAccountManagement() {
        let app = launchApp()

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.buttons["settings.accounts"].waitForExistence(timeout: 5))
        app.buttons["settings.accounts"].tap()

        XCTAssertTrue(app.scrollViews["scroll.accountManagement"].waitForExistence(timeout: 5))
        app.buttons["action.addAccount"].tap()

        let nameField = app.textFields["input.accountName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("支付宝")

        let balanceField = app.textFields["input.accountBalance"]
        XCTAssertTrue(balanceField.waitForExistence(timeout: 5))
        balanceField.tap()
        balanceField.clearText()
        balanceField.typeText("1288.66")

        let includedSwitch = app.descendants(matching: .any)["toggle.accountIncludedInAssets"]
        XCTAssertTrue(includedSwitch.waitForExistence(timeout: 5))
        includedSwitch.tap()

        app.buttons["action.saveAccount"].tap()
        XCTAssertTrue(app.staticTexts["支付宝"].waitForExistence(timeout: 5))
        let includedStatus = accountIncludedStatus("支付宝", in: app)
        XCTAssertTrue(includedStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(includedStatus.value as? String, "excluded")
        XCTAssertTrue(app.staticTexts["¥1,288.66"].waitForExistence(timeout: 5))

        let editAccountButton = editAccountButton("支付宝", in: app)
        XCTAssertTrue(editAccountButton.waitForExistence(timeout: 5))
        editAccountButton.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearText()
        nameField.typeText("支付宝余额")
        app.buttons["action.saveAccount"].tap()

        XCTAssertTrue(app.staticTexts["支付宝余额"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥1,288.66"].waitForExistence(timeout: 5))
    }

    func testCanCreateAccountTransferWithoutChangingIncomeExpenseSummary() {
        let app = launchApp()

        tapAddRecord(in: app)
        XCTAssertTrue(app.buttons["transactionType.transfer"].waitForExistence(timeout: 5))
        app.buttons["transactionType.transfer"].tap()
        XCTAssertTrue(categoryButton("transfer", in: app).waitForExistence(timeout: 5))
        categoryButton("transfer", in: app).tap()

        XCTAssertTrue(app.buttons["picker.transferSourceAccount"].waitForExistence(timeout: 5))
        app.buttons["picker.transferTargetAccount"].tap()
        let cardButton = accountButton("银行卡", in: app)
        XCTAssertTrue(cardButton.waitForExistence(timeout: 5))
        cardButton.tap()

        app.buttons["keypad.5"].tap()
        app.buttons["keypad.0"].tap()
        app.buttons["action.submitRecord"].tap()

        let transferRecord = recordElement("转账", in: app)
        XCTAssertTrue(transferRecord.waitForExistence(timeout: 5))
        XCTAssertTrue(transferRecord.label.contains("现金 -> 银行卡"))

        tabButton("洞悉", in: app).tap()
        XCTAssertTrue(app.staticTexts["summary.insights.expense.value"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["summary.insights.expense.value"].label, "¥0.00")
        XCTAssertTrue(app.staticTexts["summary.insights.income.value"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["summary.insights.income.value"].label, "¥0.00")
    }

    func testCanEditWeeklyBudgetAndSeeRemainingBudgetAfterRelaunch() {
        let app = launchApp()

        addFoodExpense(in: app)
        tabButton("计划", in: app).tap()

        XCTAssertTrue(app.buttons["action.editBudget.week"].waitForExistence(timeout: 5))
        app.buttons["action.editBudget.week"].tap()

        let amountField = app.textFields["input.budgetAmount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.clearText()
        amountField.typeText("500")
        app.buttons["action.saveBudget"].tap()

        XCTAssertTrue(app.staticTexts["budget.week.remaining"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budget.week.remaining"].label, "¥488.00")

        app.terminate()
        app.launch()
        tabButton("计划", in: app).tap()

        XCTAssertTrue(app.staticTexts["budget.week.amount"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budget.week.amount"].label, "¥500.00")
        XCTAssertTrue(app.staticTexts["budget.week.remaining"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budget.week.remaining"].label, "¥488.00")
    }

    func testPlansPageShowsBudgetSubscriptionsAndInstallmentsSections() {
        let app = launchApp()

        addFoodExpense(in: app)
        tabButton("计划", in: app).tap()

        XCTAssertTrue(app.otherElements["plans.hero.monthBudget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["plans.section.budgetOverview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["plans.section.subscriptions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["plans.section.installments"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["plans.empty.subscriptions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["plans.empty.installments"].waitForExistence(timeout: 5))
    }

    func testScreenshotShowcaseSeedProfileBootsIntoRichState() {
        let app = launchApp(seedProfile: "screenshot_showcase")

        XCTAssertTrue(recordElement("住房", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(recordElement("购物", in: app).waitForExistence(timeout: 5))

        tabButton("洞悉", in: app).tap()
        XCTAssertTrue(app.staticTexts["¥3,066.50"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥11,730.00"].waitForExistence(timeout: 5))

        tabButton("计划", in: app).tap()
        XCTAssertTrue(app.staticTexts["budget.month.amount"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budget.month.amount"].label, "¥5,200.00")

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.buttons["settings.accounts"].waitForExistence(timeout: 5))
    }

    func testCaptureScreenshotShowcaseGallery() throws {
        let app = launchApp(seedProfile: "screenshot_showcase")

        saveScreenshot(named: "01-transactions-home")

        app.buttons["action.openTransactionSearch"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        saveScreenshot(named: "02-transactions-search")
        app.buttons["action.closeTransactionSearch"].tap()

        let housingRecord = recordElement("住房", in: app)
        XCTAssertTrue(housingRecord.waitForExistence(timeout: 5))
        housingRecord.tap()
        XCTAssertTrue(app.scrollViews["page.recordDetail"].waitForExistence(timeout: 5))
        saveScreenshot(named: "03-record-detail")
        app.buttons["action.closeRecordDetail"].tap()

        tabButton("洞悉", in: app).tap()
        XCTAssertTrue(app.staticTexts["¥3,066.50"].waitForExistence(timeout: 5))
        saveScreenshot(named: "04-insights")

        tabButton("计划", in: app).tap()
        XCTAssertTrue(app.otherElements["plans.hero.monthBudget"].waitForExistence(timeout: 5))
        saveScreenshot(named: "05-plans")

        tabButton("我的", in: app).tap()
        XCTAssertTrue(app.buttons["settings.accounts"].waitForExistence(timeout: 5))
        saveScreenshot(named: "06-settings")

        app.buttons["settings.accounts"].tap()
        XCTAssertTrue(app.scrollViews["scroll.accountManagement"].waitForExistence(timeout: 5))
        saveScreenshot(named: "07-accounts")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["settings.categories"].waitForExistence(timeout: 5))
        app.buttons["settings.categories"].tap()
        XCTAssertTrue(app.scrollViews["scroll.categoryManagement"].waitForExistence(timeout: 5))
        saveScreenshot(named: "08-categories-expense")

        let incomeButton = app.buttons["categoryKind.income"]
        XCTAssertTrue(incomeButton.waitForExistence(timeout: 5))
        incomeButton.tap()
        saveScreenshot(named: "09-categories-income")

        tabButton("明细", in: app).tap()
        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton("餐饮", in: app).waitForExistence(timeout: 5))
        saveScreenshot(named: "10-add-record")
    }

    private func launchApp(seedProfile: String? = nil, languageCode: String? = "zh-Hans") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NUMI_UI_TEST_STORE_ID"] = uiTestStoreID
        if let languageCode {
            app.launchEnvironment["NUMI_UI_TEST_APP_LANGUAGE"] = languageCode
        }
        if let seedProfile {
            app.launchEnvironment["NUMI_SEED_PROFILE"] = seedProfile
            app.launchEnvironment["NUMI_SEED_RESET"] = "1"
        }
        app.launch()
        return app
    }

    private func saveScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addFoodExpense(in app: XCUIApplication) {
        addExpense(in: app, categoryName: "餐饮", amountDigits: ["1", "2"])
    }

    private func addExpense(
        in app: XCUIApplication,
        categoryName: String,
        amountDigits: [String],
        note: String? = nil,
        accountName: String? = nil,
        dateShortcut: String? = nil
    ) {
        tapAddRecord(in: app)
        XCTAssertTrue(categoryButton(categoryName, in: app).waitForExistence(timeout: 5))

        categoryButton(categoryName, in: app).tap()
        for digit in amountDigits {
            app.buttons["keypad.\(digit)"].tap()
        }
        if let accountName {
            app.buttons["picker.inlineRecordAccount"].tap()
            let accountButton = accountButton(accountName, in: app)
            XCTAssertTrue(accountButton.waitForExistence(timeout: 5))
            accountButton.tap()
        }
        if let dateShortcut {
            applyDateShortcut(dateShortcut, in: app)
        }
        if let note {
            let noteField = app.textFields["input.inlineRecordNote"]
            XCTAssertTrue(noteField.waitForExistence(timeout: 5))
            noteField.tap()
            noteField.typeText(note)
        }
        if app.buttons["action.keyboardSubmitRecord"].exists {
            app.buttons["action.keyboardSubmitRecord"].tap()
        } else {
            app.buttons["action.submitRecord"].tap()
        }
    }

    private func XCTAssertSavedFoodExpenseExists(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let savedRecord = recordElement("餐饮", in: app)
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5), file: file, line: line)
        let amount = recordAmountElement("餐饮", in: app)
        XCTAssertTrue(amount.waitForExistence(timeout: 5), file: file, line: line)
    }

    private func tapAddRecord(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let floatingButton = app.buttons["button.addRecord"]
        if floatingButton.waitForExistence(timeout: 2) {
            floatingButton.tap()
            return
        }

        let emptyButton = app.buttons["home.empty.primaryAction"]
        XCTAssertTrue(emptyButton.waitForExistence(timeout: 5), file: file, line: line)
        emptyButton.tap()
    }

    private func applyDateShortcut(_ title: String, in app: XCUIApplication) {
        let shortcut = app.buttons["keypad.openDatePicker"]
        let expectedKey: String?
        switch title {
        case "今天", "Today":
            expectedKey = "today"
        case "昨天", "Yesterday":
            expectedKey = "yesterday"
        case "前天", "Day Before Yesterday":
            expectedKey = "dayBeforeYesterday"
        default:
            expectedKey = nil
        }
        for _ in 0..<3 {
            XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
            if let expectedKey,
               let value = shortcut.value as? String,
               value.contains("shortcut.\(expectedKey)") {
                return
            }
            if shortcut.label == title {
                return
            }
            shortcut.tap()
        }
        if let expectedKey,
           let value = shortcut.value as? String {
            XCTAssertTrue(value.contains("shortcut.\(expectedKey)"))
        } else {
            XCTAssertEqual(shortcut.label, title)
        }
    }

    private func tabButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let nativeTabButton = app.tabBars.buttons[title]
        if nativeTabButton.exists {
            return nativeTabButton
        }
        return app.buttons["tab.\(tabIdentifier(for: title))"]
    }

    private func waitForLabel(
        _ expected: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.waitForExistence(timeout: 0.2), element.label == expected {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Expected label '\(expected)', got '\(element.label)'", file: file, line: line)
    }

    private func categoryButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.buttons["category.\(name)"]
        if direct.exists {
            return direct
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func accountButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.buttons["account.\(name)"]
        if direct.exists {
            return direct
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func recordElement(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["record.\(name)"]
        if direct.exists {
            return direct
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", name))
            .firstMatch
    }

    private func searchRecordElement(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["search.record.\(name)"]
        if direct.exists {
            return direct
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", name))
            .firstMatch
    }

    private func recordAmountElement(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["record.amount.\(name)"]
        if direct.exists {
            return direct
        }
        return recordElement(name, in: app).staticTexts.element(boundBy: 0)
    }

    private func categoryToggle(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["toggle.category.\(name)"]
        if direct.exists {
            return direct
        }
        return app.switches.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func accountToggle(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["toggle.account.\(name)"]
        if direct.exists {
            return direct
        }
        return app.switches.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func accountIncludedStatus(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.descendants(matching: .any)["account.includedStatus.\(name)"]
        if direct.exists {
            return direct
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }

    private func editAccountButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let direct = app.buttons["action.editAccount.\(name)"]
        if direct.exists {
            return direct
        }
        return app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "action.editAccount.")).firstMatch
    }

    private func tabIdentifier(for title: String) -> String {
        switch title {
        case "明细", "Transactions":
            return "transactions"
        case "洞悉", "Insights":
            return "insights"
        case "计划", "Plans":
            return "plans"
        case "我的", "Settings":
            return "settings"
        default:
            return title
        }
    }

    private func assertBottomBarVisible(
        in app: XCUIApplication,
        baselineAddButtonFrame: CGRect? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let addButton = app.buttons["button.addRecord"]
        let rail = app.otherElements["tab.rail"]

        XCTAssertTrue(addButton.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(rail.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(addButton.isHittable, file: file, line: line)
        XCTAssertTrue(rail.isHittable, file: file, line: line)

        if let baselineAddButtonFrame {
            XCTAssertLessThan(abs(addButton.frame.minY - baselineAddButtonFrame.minY), 36, file: file, line: line)
        }
    }

    private func assertBottomBarHiddenAfterScroll(
        in app: XCUIApplication,
        baselineAddButtonFrame: CGRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let addButton = app.buttons["button.addRecord"]
        let rail = app.otherElements["tab.rail"]

        XCTAssertTrue(addButton.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(rail.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertGreaterThan(addButton.frame.minY, baselineAddButtonFrame.maxY, file: file, line: line)
        XCTAssertGreaterThan(rail.frame.minY, baselineAddButtonFrame.minY + 36, file: file, line: line)
        XCTAssertFalse(addButton.isHittable && rail.isHittable, file: file, line: line)
    }
}

private extension XCUIElement {
    func clearText() {
        guard let value = value as? String, !value.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        typeText(deleteString)
    }

}
